# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'open3'
require 'stringio'
require 'tmpdir'

class RbsTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  TOOLING = File.join(ROOT, 'examples/tooling')

  def test_tooling_example_signatures_are_current
    status, rbs = run_cli(TOOLING, 'rbs', '-o', '-', 'main.rb')

    assert_equal 0, status
    assert_equal File.read(File.join(TOOLING, 'sig/generated/carton.rbs')), rbs
  end

  def test_constant_export_bound_to_its_own_name_needs_nothing
    rbs =
      generate(
        'main.rb' => "Billing = import_relative 'billing'\n",
        'billing.rb' => "module Billing; end\nexport Billing\n",
      )

    assert_includes rbs, '("billing" path) -> singleton(::Billing)'
    refute_includes rbs, 'Constants bound to imports'
  end

  def test_constant_export_bound_to_another_name_is_an_alias
    rbs =
      generate(
        'main.rb' =>
          "Invoicing = import_relative 'billing'\nUsers = import_relative 'user'\n",
        'billing.rb' => "module Billing; end\nexport Billing\n",
        'user.rb' => "class User; end\nexport User\n",
      )

    assert_includes rbs, 'module Invoicing = ::Billing'
    assert_includes rbs, 'class Users = ::User'
  end

  def test_export_of_a_plain_value_is_untyped
    rbs =
      generate(
        'main.rb' => "Greeting = import_relative 'greeting'\n",
        'greeting.rb' => "export 'hello'\n",
      )

    assert_includes rbs, 'Greeting: untyped'
    refute_includes rbs, 'module Kernel'
  end

  def test_keyword_export_is_a_record
    rbs =
      generate(
        'main.rb' => "Info = import_relative 'info'\n",
        'info.rb' => "export VERSION: '1', answer: 42, other: compute\n",
      )

    assert_includes rbs,
                    'Info: { VERSION: ::String, answer: ::Integer, other: untyped }'
  end

  def test_self_export_is_typed
    rbs =
      generate(
        'main.rb' => "import_relative 'version'\n",
        'version.rb' => "self.export version: '1.0'\n",
      )

    assert_includes rbs, '("version" path) -> { version: ::String }'
  end

  def test_literal_hash_export_is_a_record
    rbs =
      generate(
        'main.rb' => "Info = import_relative 'info'\n",
        'info.rb' => "export({ enabled: false, default: nil, tags: [] })\n",
      )

    assert_includes rbs,
                    'Info: { enabled: bool, default: nil, tags: ::Array[untyped] }'
  end

  # The same relative path names two Cartons in two files, so a single
  # overload would be wrong for one of them.
  def test_ambiguous_relative_path_gets_no_overload
    rbs =
      generate(
        'main.rb' => "import_relative 'a/main'\nimport_relative 'b/main'\n",
        'a/main.rb' => "import_relative 'tools'\nexport x: 1\n",
        'a/tools.rb' => "export x: 1\n",
        'b/main.rb' => "import_relative 'tools'\nexport x: 1\n",
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
                      '("tools" path) -> { x: ::Integer }'
    end
  end

  # End to end: Steep accepts the tooling example with its generated RBS,
  # and catches a misuse of an exported module's annotated type.
  def test_steep_checks_imports_with_generated_signatures
    assert_steep(TOOLING)

    Dir.mktmpdir do |dir|
      FileUtils.cp_r("#{TOOLING}/.", dir)
      # Steep resolves signature paths relative to the Steepfile.
      carton_sig =
        Pathname(ROOT).join('sig').relative_path_from(File.realpath(dir))
      File.write(
        File.join(dir, 'Steepfile'),
        "target(:app) { signature 'sig', '#{carton_sig}'; check 'main.rb' }\n",
      )
      File.write(
        File.join(dir, 'main.rb'),
        "Pricing.total(40).upcase\n",
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

  def test_unchanged_output_is_not_rewritten
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "import_relative 'tools'\n")
      File.write(File.join(dir, 'tools.rb'), "export x: 1\n")
      run_cli(dir, 'rbs', 'main.rb')
      path = File.join(dir, 'sig/generated/carton.rbs')
      File.utime(0, 0, path)

      status, output = run_cli(dir, 'rbs', 'main.rb')

      assert_equal 0, status
      assert_equal "sig/generated/carton.rbs is up to date\n", output
      assert_equal 0, File.mtime(path).to_i
    end
  end

  def test_check_reports_fresh_stale_and_missing_output
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "import_relative 'tools'\n")
      File.write(File.join(dir, 'tools.rb'), "export x: 1\n")
      path = File.join(dir, 'sig/generated/carton.rbs')

      missing =
        "sig/generated/carton.rbs is missing: run carton rbs to write it\n"

      assert_equal [1, missing], run_cli(dir, 'rbs', '--check', 'main.rb')
      refute File.exist?(path)

      run_cli(dir, 'rbs', 'main.rb')
      assert_equal [0, "sig/generated/carton.rbs is up to date\n"],
                   run_cli(dir, 'rbs', '--check', 'main.rb')

      File.write(File.join(dir, 'tools.rb'), "export x: 'one'\n")
      before = File.read(path)
      status, output = run_cli(dir, 'rbs', '--check', 'main.rb')

      assert_equal 1, status
      assert_match(
        %r{\Asig/generated/carton\.rbs is stale from line \d+: run carton rbs},
        output,
      )
      assert_equal before, File.read(path)
    end
  end

  def test_check_needs_an_output_file
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'main.rb'), "p 1\n")
      err = StringIO.new
      status =
        Dir.chdir(dir) do
          Carton::Tools::CLI.start(
            %w[rbs --check -o - main.rb],
            out: StringIO.new,
            err:,
          )
        end

      assert_equal 2, status
      assert_match(/--check/, err.string)
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
    status = Dir.chdir(dir) { Carton::Tools::CLI.start(argv, out:, err:) }
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
