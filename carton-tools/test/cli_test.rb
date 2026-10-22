# frozen_string_literal: true

require_relative 'test_helper'
require 'stringio'
require 'json'
require 'tmpdir'
require 'fileutils'

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

  def test_version_prints_the_version
    %w[-v --version].each do |flag|
      assert_equal [0, "carton #{Carton::Tools::VERSION}\n", ''], run_cli(flag)
    end
  end

  def test_help_command_prints_usage
    assert_equal run_cli('--help'), run_cli('help')
  end

  # OptionParser's own --help and --version print to $stdout and exit.
  def test_command_help_and_version_return_a_status
    %w[check rbs].each do |command|
      status, out, err = run_cli(command, '--help')

      assert_equal 0, status
      assert_match(/\AUsage: carton #{command} \[options\] PATH\.\.\./, out)
      assert_match(/^    -h, --help /, out)
      assert_empty err
      assert_equal [status, out, err], run_cli('help', command)
      assert_equal [status, out, err], run_cli(command, '-h')
      assert_equal [0, "carton #{Carton::Tools::VERSION}\n", ''],
                   run_cli(command, '--version')
    end
  end

  def test_help_for_an_unknown_command_fails
    status, out, err = run_cli('help', 'run')

    assert_equal 2, status
    assert_empty out
    assert_match(/\Acarton: unknown command run$/, err)
  end

  def test_missing_path_fails
    status, _, err = run_cli('check', 'nope.rb')

    assert_equal 2, status
    assert_equal "carton: nope.rb: No such file or directory\n", err
  end

  def test_directory_scan_skips_vendor_bundle_and_excluded_globs
    Dir.mktmpdir do |dir|
      {
        'app/main.rb' => "p 1\n",
        'app/tmp/broken.rb' => "def broken(\n",
        'app/vendor/bundle/gems/x/x.rb' => "def broken(\n",
      }.each do |path, source|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), source)
      end
      Dir.chdir(dir) do
        status, out, = run_cli('check', 'app')

        assert_equal 1, status
        assert_match(%r{^app/tmp/broken\.rb:}, out)
        refute_match(/vendor/, out)
        assert_equal [0, "1 file, 0 Cartons, 0 errors, 0 warnings\n", ''],
                     run_cli('check', '--exclude', 'tmp', 'app')
        assert_equal [0, "1 file, 0 Cartons, 0 errors, 0 warnings\n", ''],
                     run_cli('check', '--exclude', '**/*broken*', 'app')
      end
    end
  end

  def test_directory_without_ruby_files_fails
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, 'empty/vendor/bundle'))
      File.write(File.join(dir, 'empty/vendor/bundle/x.rb'), "p 1\n")
      status, out, err = Dir.chdir(dir) { run_cli('check', 'empty') }

      assert_equal 2, status
      assert_empty out
      assert_equal "carton: no Ruby files in empty\n", err
    end
  end

  def test_unreadable_file_fails
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "p 1\n")
      File.chmod(0o000, File.join(dir, 'main.rb'))
      skip 'running as root' if File.readable?(File.join(dir, 'main.rb'))
      status, _, err = Dir.chdir(dir) { run_cli('check', 'main.rb') }

      assert_equal 2, status
      assert_match(/\Acarton: \S*main\.rb: Permission denied\n\z/, err)
    end
  end

  def test_rbs_output_to_a_directory_fails
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "p 1\n")
      Dir.mkdir(File.join(dir, 'sig'))
      status, _, err = Dir.chdir(dir) { run_cli('rbs', '-o', 'sig', 'main.rb') }

      assert_equal 2, status
      assert_equal "carton: sig: Is a directory\n", err
    end
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
        'version' => 1,
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
      'version' => 1,
      'problems' => [
        {
          'level' => 'warning',
          'rule' => 'unused-import',
          'file' => 'main.rb',
          'line' => 1,
          'column' => 10,
          'message' =>
            'Unused is bound to an import of the other.rb Carton but never used',
        },
        {
          'level' => 'error',
          'rule' => 'export-twice',
          'file' => 'other.rb',
          'line' => 2,
          'column' => 1,
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
