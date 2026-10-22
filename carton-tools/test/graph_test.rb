# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'stringio'
require 'tmpdir'

# `carton graph` and `carton why` read the same import graph.
class GraphTest < Minitest::Test
  FILES = {
    'main.rb' =>
      "Billing = import_relative 'billing'\nMath = import_relative 'lib/math'\n",
    'billing.rb' =>
      "require_relative 'billing/tax'\ndef report = import_relative('report')\n" \
        "export Billing\n",
    'billing/tax.rb' =>
      "module Billing\n  Math = import_relative '../lib/math'\nend\n",
    'lib/math.rb' => "export({})\n",
    'report.rb' => "export({})\n",
  }.freeze

  def test_mermaid_is_the_default
    status, out = run_cli('graph', 'main.rb')

    assert_equal 0, status
    assert_equal <<~MERMAID, out
      flowchart LR
        n0(["Main"])
        n1["billing.rb"]
        n2["lib/math.rb"]
        n3["report.rb"]
        n0 --> n1
        n0 --> n2
        n1 --> n2
        n1 -.-> n3
    MERMAID
    assert_equal run_cli('graph', 'main.rb'),
                 run_cli('graph', '--format', 'mermaid', 'main.rb')
  end

  def test_dot
    status, out = run_cli('graph', '--format', 'dot', 'main.rb')

    assert_equal 0, status
    assert_equal <<~DOT, out
      digraph cartons {
        n0 [label="Main", shape=box];
        n1 [label="billing.rb"];
        n2 [label="lib/math.rb"];
        n3 [label="report.rb"];
        n0 -> n1;
        n0 -> n2;
        n1 -> n2;
        n1 -> n3 [style=dashed];
      }
    DOT
  end

  def test_an_app_without_imports_is_main_alone
    status, out = run_cli('graph', 'report.rb')

    assert_equal [0, "flowchart LR\n  n0([\"Main\"])\n"], [status, out]
  end

  def test_why_prints_the_shortest_chain_of_imports
    status, out = run_cli('why', 'main.rb', 'report.rb')

    assert_equal 0, status
    assert_equal "billing/tax.rb:2:10: import_relative '../lib/math' -> lib/math.rb\n",
                 run_cli('why', 'billing.rb', 'lib/math.rb').last
    assert_equal "main.rb:1:11: import_relative 'billing' -> billing.rb\n" \
                   "billing.rb:2:14: import_relative 'report' -> report.rb\n",
                 out
  end

  def test_why_names_a_file_inside_the_target_carton
    status, out = run_cli('why', 'main.rb', 'billing/tax.rb')

    assert_equal 0, status
    assert_equal "main.rb:1:11: import_relative 'billing' -> billing.rb\n", out
  end

  def test_why_without_a_path_fails
    assert_equal [1, "report.rb does not import billing.rb\n"],
                 run_cli('why', 'report.rb', 'billing.rb')
  end

  def test_why_needs_exactly_two_operands
    out = StringIO.new
    err = StringIO.new
    status = Carton::Tools::CLI.start(%w[why main.rb], out:, err:)

    assert_equal 2, status
    assert_match(/\AUsage: carton why \[options\] FROM TO$/, err.string)
  end

  private

  def run_cli(*argv)
    Dir.mktmpdir do |dir|
      FILES.each do |path, source|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), source)
      end
      out = StringIO.new
      err = StringIO.new
      status = Dir.chdir(dir) { Carton::Tools::CLI.start(argv, out:, err:) }
      assert_empty err.string
      [status, out.string]
    end
  end
end
