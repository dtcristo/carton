# frozen_string_literal: true

require_relative '../test_helper'
require 'carton/cli'
require 'fileutils'
require 'open3'
require 'stringio'
require 'tmpdir'

class RbsTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  MINIMAL = File.join(ROOT, 'examples/minimal')

  def test_minimal_example_signatures_are_current
    status, rbs = run_cli(MINIMAL, 'rbs', '-o', '-', 'main.rb')

    assert_equal 0, status
    assert_equal File.read(File.join(MINIMAL, 'sig/generated/carton.rbs')), rbs
  end

  def test_default_export_bound_to_its_own_name_needs_nothing
    rbs =
      generate(
        'main.rb' => "Billing = import_relative 'billing'\n",
        'billing.rb' => "module Billing; end\nexport_default Billing\n",
      )

    assert_includes rbs, '("billing" path) -> singleton(::Billing)'
    refute_includes rbs, 'Constants bound to imports'
  end

  def test_default_export_bound_to_another_name_is_an_alias
    rbs =
      generate(
        'main.rb' =>
          "Invoicing = import_relative 'billing'\nUsers = import_relative 'user'\n",
        'billing.rb' => "module Billing; end\nexport_default Billing\n",
        'user.rb' => "class User; end\nexport_default User\n",
      )

    assert_includes rbs, 'module Invoicing = ::Billing'
    assert_includes rbs, 'class Users = ::User'
  end

  def test_default_export_of_a_value_is_untyped
    rbs =
      generate(
        'main.rb' => "Greeting = import_relative 'greeting'\n",
        'greeting.rb' => "export_default 'hello'\n",
      )

    assert_includes rbs, 'Greeting: untyped'
    refute_includes rbs, 'module Kernel'
  end

  def test_named_exports_become_a_module
    rbs =
      generate(
        'main.rb' => "Tools = import_relative 'tools'\n",
        'tools.rb' => <<~RUBY,
          PI = 3.14
          #: (Integer n) -> Integer
          def double(n) = n * 2
          def helper(x, y = 1) = x
          export :PI, :double, :helper, VERSION: '1', answer: 42
        RUBY
      )

    assert_includes rbs, <<~RBS
      module Carton::Exports::Tools
        extend ::Carton::ExportMethods
        def self.double: (Integer n) -> Integer
        def self.helper: (untyped x, ?untyped y) -> untyped
        VERSION: ::String
        def self.answer: () -> ::Integer
        PI: ::Float
      end
    RBS
    assert_includes rbs, 'module Tools = ::Carton::Exports::Tools'
  end

  def test_bare_carton_surface_becomes_a_module
    rbs =
      generate(
        'main.rb' => "Util = import_relative 'util'\n",
        'util.rb' => "LIMIT = 3\nclass Helper; end\ndef run(x) = x\n",
      )

    assert_includes rbs, <<~RBS
      module Carton::Exports::Util
        extend ::Carton::ExportMethods
        def self.run: (untyped x) -> untyped
        LIMIT: ::Integer
        Helper: singleton(::Helper)
      end
    RBS
  end

  def test_cartons_sharing_a_name_get_their_directory
    rbs =
      generate(
        'main.rb' =>
          "A = import_relative 'a/math'\nB = import_relative 'b/math'\n",
        'a/math.rb' => "export x: 1\n",
        'b/math.rb' => "export y: 1\n",
      )

    assert_includes rbs, 'module Carton::Exports::AMath'
    assert_includes rbs, 'module Carton::Exports::BMath'
  end

  # The same relative path names two Cartons in two files, so a single
  # overload would be wrong for one of them.
  def test_ambiguous_relative_path_gets_no_overload
    rbs =
      generate(
        'main.rb' => "import_relative 'a/main'\nimport_relative 'b/main'\n",
        'a/main.rb' => "import_relative 'tools'\n",
        'a/tools.rb' => "export x: 1\n",
        'b/main.rb' => "import_relative 'tools'\n",
        'b/tools.rb' => "export y: 1\n",
      )

    refute_includes rbs, '("tools" path)'
    assert_includes rbs, '("a/main" path)'
  end

  def test_writes_the_default_output_file
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "import_relative 'tools'\n")
      File.write(File.join(dir, 'tools.rb'), "export x: 1\n")

      status, output = run_cli(dir, 'rbs', 'main.rb')

      assert_equal 0, status
      assert_equal "Wrote sig/generated/carton.rbs\n", output
      assert_includes File.read(File.join(dir, 'sig/generated/carton.rbs')),
                      'module Carton::Exports::Tools'
    end
  end

  # End to end: Steep accepts the minimal example with its generated RBS,
  # and catches a misuse of a Named Export's annotated type.
  def test_steep_checks_imports_with_generated_signatures
    assert_steep(MINIMAL)

    Dir.mktmpdir do |dir|
      FileUtils.cp_r("#{MINIMAL}/.", dir)
      # Steep resolves signature paths relative to the Steepfile.
      carton_sig =
        Pathname(ROOT).join('sig').relative_path_from(File.realpath(dir))
      File.write(
        File.join(dir, 'Steepfile'),
        "target(:app) { signature 'sig', '#{carton_sig}'; check 'main.rb' }\n",
      )
      File.write(
        File.join(dir, 'main.rb'),
        "MathTools.percent(40, 10).upcase\n",
        mode: 'a',
      )

      output = assert_steep(dir, success: false)
      assert_match(
        /main\.rb:\d+:\d+: \[error\] Type `::Float` does not have method `upcase`/,
        output,
      )
      assert_match(/Detected 1 problem/, output)
    end
  end

  private

  def generate(files)
    Dir.mktmpdir do |dir|
      files.each do |path, source|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), source)
      end
      status, rbs = run_cli(dir, 'rbs', '-o', '-', 'main.rb')
      assert_equal 0, status
      rbs
    end
  end

  def run_cli(dir, *argv)
    out = StringIO.new
    err = StringIO.new
    status = Dir.chdir(dir) { Carton::CLI.start(argv, out:, err:) }
    assert_empty err.string
    [status, out.string]
  end

  # Tests run outside the dev bundle, so Steep runs through it explicitly.
  def assert_steep(dir, success: true)
    env = { 'BUNDLE_GEMFILE' => File.join(ROOT, 'Gemfile'), 'RUBY_BOX' => nil }
    output, status =
      Open3.capture2e(env, 'bundle', 'exec', 'steep', 'check', chdir: dir)
    output = output.force_encoding(Encoding::UTF_8)
    assert_equal success, status.success?, output
    output
  end
end
