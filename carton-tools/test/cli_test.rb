# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'

class CliTest < Minitest::Test
  def test_help_prints_usage
    status, out, err = run_cli('--help')

    assert_equal 0, status
    assert_match(/\AUsage: carton COMMAND/, out)
    assert_match(/^  rbs /, out)
    assert_match(/^  check /, out)
    assert_empty err
  end

  def test_no_command_prints_usage_and_fails
    status, out, err = run_cli

    assert_equal 2, status
    assert_empty out
    assert_match(/\AUsage: carton COMMAND/, err)
  end

  def test_unknown_command_fails
    status, _, err = run_cli('run', 'main.rb')

    assert_equal 2, status
    assert_match(/\Acarton: unknown command run$/, err)
  end

  def test_command_without_paths_prints_its_usage
    status, _, err = run_cli('check')

    assert_equal 2, status
    assert_match(/\AUsage: carton check \[options\] PATH\.\.\./, err)
  end

  def test_missing_path_fails
    status, _, err = run_cli('check', 'nope.rb')

    assert_equal 2, status
    assert_match(/\Acarton: No such file or directory/, err)
  end

  def test_bad_option_fails
    status, _, err = run_cli('rbs', '--nope', 'main.rb')

    assert_equal 2, status
    assert_equal "carton: invalid option: --nope\n", err
  end

  private

  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = Carton::Tools::CLI.start(argv, out:, err:)
    [status, out.string, err.string]
  end
end
