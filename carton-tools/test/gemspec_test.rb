# frozen_string_literal: true

require_relative 'test_helper'
require 'carton/version'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class ToolsGemspecTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)
  TOOLS = File.join(ROOT, 'carton-tools')

  # carton-tools reads Carton's internals, so the two are released together.
  def test_version_matches_carton
    assert_equal Carton::VERSION, Carton::Tools::VERSION
    assert_equal Carton::VERSION, tools_specification.version.to_s
  end

  def test_depends_on_exactly_its_own_carton_and_on_prism
    dependencies =
      tools_specification.runtime_dependencies.to_h do |dependency|
        [dependency.name, dependency.requirement.to_s]
      end

    assert_equal(
      { 'carton' => "= #{Carton::VERSION}", 'prism' => '>= 1.8' },
      dependencies,
    )
  end

  def test_packages_the_command_library_and_docs
    expected =
      Dir.glob(%w[exe/* lib/**/*.rb], base: TOOLS) + %w[LICENSE.txt README.md]

    assert_equal expected.sort, tools_specification.files.sort
    assert_equal ['carton'], tools_specification.executables
  end

  # Build both gems, install them into an empty gem home, and run the
  # installed command, so a file missing from either package fails here.
  # `gem install --local --install-dir` does not count Ruby's default prism
  # as installed, so dependencies are skipped; the command still activates
  # the default prism when it runs.
  def test_built_gems_install_and_run
    Dir.mktmpdir('carton-tools-gem') do |dir|
      home = install_built_gems(dir)
      File.write(File.join(dir, 'main.rb'), "import_relative 'missing'\n")
      env = { 'GEM_HOME' => home, 'GEM_PATH' => home }

      output, status =
        Open3.capture2e(
          clean_env.merge(env),
          RbConfig.ruby,
          File.join(home, 'bin', 'carton'),
          'check',
          'main.rb',
          chdir: dir,
        )

      assert_equal 1, status.exitstatus, output
      assert_match(/main\.rb:1: error: /, output)
    end
  end

  private

  # Returns the gem home both freshly built gems were installed into.
  def install_built_gems(dir)
    gems =
      [[ROOT, 'carton'], [TOOLS, 'carton-tools']].map do |root, name|
        file = File.join(dir, "#{name}.gem")
        run_ruby(
          root,
          '-S',
          'gem',
          'build',
          "#{name}.gemspec",
          '--output',
          file,
        )
        file
      end
    home = File.join(dir, 'home')
    run_ruby(
      dir,
      '-S',
      'gem',
      'install',
      '--local',
      '--no-document',
      '--ignore-dependencies',
      '--install-dir',
      home,
      *gems,
    )
    home
  end

  def tools_specification
    Gem::Specification.load(File.join(TOOLS, 'carton-tools.gemspec'))
  end

  def clean_env
    ENV.keys.grep(/\A(BUNDLER?_|RUBY(OPT|LIB)\z)/).to_h { |key| [key, nil] }
  end

  def run_ruby(dir, *)
    output, error, status =
      Open3.capture3(clean_env, RbConfig.ruby, *, chdir: dir)
    assert status.success?, [output, error].reject(&:empty?).join("\n")
    output
  end
end
