# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'json'
require 'tmpdir'

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

  def test_check_json_reports_a_clean_project_without_running_it
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "raise 'must not execute'\n")
      status, out, err =
        Dir.chdir(dir) { run_cli('check', '--format', 'json', 'main.rb') }

      assert_equal 0, status
      assert_empty err
      expected = {
        'problems' => [],
        'files' => 1,
        'cartons' => 0,
        'errors' => 0,
        'warnings' => 0,
      }
      assert_equal expected, JSON.parse(out)
    end
  end

  def test_check_json_reports_problems_counts_and_relative_paths
    expected = {
      'problems' => [
        {
          'level' => 'warning',
          'file' => 'main.rb',
          'line' => 1,
          'message' =>
            'Unused is bound to an import of the other Carton but never used',
        },
        {
          'level' => 'error',
          'file' => 'other.rb',
          'line' => 2,
          'message' => 'export may be called only once per Entrypoint',
        },
      ],
      'files' => 2,
      'cartons' => 1,
      'errors' => 1,
      'warnings' => 1,
    }

    Dir.mktmpdir do |dir|
      File.write(
        File.join(dir, 'main.rb'),
        "Unused = import_relative 'other'\n",
      )
      File.write(File.join(dir, 'other.rb'), "export 1\nexport 2\n")
      status, out, err =
        Dir.chdir(dir) { run_cli('check', '--format=json', 'main.rb') }

      assert_equal 1, status
      assert_empty err
      assert_equal expected, JSON.parse(out)
    end
  end

  def test_json_preserves_warning_and_strict_exit_statuses
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "import_relative ENV['TARGET']\n")
      Dir.chdir(dir) do
        status, out, err = run_cli('check', '--format', 'json', 'main.rb')
        strict_status, strict_out, strict_err =
          run_cli('check', '--format', 'json', '--strict', 'main.rb')

        assert_equal 0, status
        assert_equal 1, strict_status
        assert_empty err
        assert_empty strict_err
        assert_equal JSON.parse(out), JSON.parse(strict_out)
        assert_equal 0, JSON.parse(out).fetch('errors')
        assert_equal 1, JSON.parse(out).fetch('warnings')
      end
    end
  end

  def test_explicit_text_output_matches_the_default
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "import_relative 'missing'\n")
      Dir.chdir(dir) do
        assert_equal run_cli('check', 'main.rb'),
                     run_cli('check', '--format', 'text', 'main.rb')
        _, out, = run_cli('check', '--format', 'json', 'main.rb')
        problem = JSON.parse(out).fetch('problems').first

        assert_equal 'main.rb', problem.fetch('file')
        assert_equal 'cannot load such file -- missing (tried missing.rb and missing/lib/missing.rb in .)',
                     problem.fetch('message')
      end
    end
  end

  def test_invalid_check_format_is_a_usage_error
    status, out, err = run_cli('check', '--format', 'yaml', 'main.rb')

    assert_equal 2, status
    assert_empty out
    assert_equal "carton: invalid argument: --format yaml\n", err
  end

  private

  def run_cli(*argv)
    out = StringIO.new
    err = StringIO.new
    status = Carton::Tools::CLI.start(argv, out:, err:)
    [status, out.string, err.string]
  end
end
