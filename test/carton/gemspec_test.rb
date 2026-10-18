# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class GemspecTest < Minitest::Test
  INSTALLED_IMPORT = <<~'RUBY'
    require 'carton'
    puts $LOADED_FEATURES.grep(%r{/carton\.rb\z})
    puts import_relative('greeting')
  RUBY

  def test_required_ruby_version_accepts_4_0_7_and_later
    requirement = carton_specification.required_ruby_version

    assert requirement.satisfied_by?(Gem::Version.new('4.0.7'))
    assert requirement.satisfied_by?(Gem::Version.new('4.0.8'))
    assert requirement.satisfied_by?(Gem::Version.new('4.1.0'))
  end

  def test_required_ruby_version_rejects_older_rubies
    requirement = carton_specification.required_ruby_version

    refute requirement.satisfied_by?(Gem::Version.new('4.0.6'))
    refute requirement.satisfied_by?(Gem::Version.new('4.0.5'))
    refute requirement.satisfied_by?(Gem::Version.new('4.0.2'))
    refute requirement.satisfied_by?(Gem::Version.new('3.4.0'))
  end

  def test_description_names_ruby_4_0_7_baseline
    assert_includes carton_specification.description, 'Ruby 4.0.7'
  end

  # The gem ships the library, its signatures, and top-level docs only, and
  # the list does not depend on git, so it also builds from a source archive.
  # The carton command ships in carton-tools.
  def test_packages_only_library_signatures_and_docs
    root = File.expand_path('../..', __dir__)
    expected =
      Dir.glob(%w[lib/**/*.rb sig/**/*.rbs], base: root) +
        %w[CHANGELOG.md LICENSE.txt README.md]

    assert_equal expected.sort, carton_specification.files.sort
    assert_empty carton_specification.executables
  end

  # Every gem built on Carton depends on it, so it pulls in nothing else.
  def test_has_no_dependencies
    assert_empty carton_specification.dependencies
  end

  # Build the gem, install it into an empty gem home, and import through the
  # installed copy, so a file missing from the package fails here.
  def test_built_gem_installs_and_imports
    Dir.mktmpdir('carton-gem') do |dir|
      home = install_built_gem(dir)
      File.write(File.join(dir, 'greeting.rb'), "export 'hello'\n")
      env = { 'GEM_HOME' => home, 'GEM_PATH' => home, 'RUBY_BOX' => '1' }

      output = run_ruby(dir, '-e', INSTALLED_IMPORT, env:)

      loaded, greeting = output.lines(chomp: true)
      assert loaded.start_with?(File.realpath(home)),
             "loaded #{loaded}, not the installed gem"
      assert_equal 'hello', greeting
    end
  end

  private

  def carton_specification
    path = File.expand_path('../../carton.gemspec', __dir__)
    Gem::Specification.load(path)
  end

  # Returns the gem home the freshly built gem was installed into.
  def install_built_gem(dir)
    gem_file = File.join(dir, 'carton.gem')
    home = File.join(dir, 'home')
    root = File.expand_path('../..', __dir__)
    run_ruby(root, '-S', 'gem', 'build', 'carton.gemspec', '--output', gem_file)
    run_ruby(
      dir,
      '-S',
      'gem',
      'install',
      '--local',
      '--no-document',
      '--install-dir',
      home,
      gem_file,
    )
    home
  end

  def run_ruby(dir, *, env: {})
    clean =
      ENV.keys.grep(/\A(BUNDLER?_|RUBY(OPT|LIB)\z)/).to_h { |key| [key, nil] }
    output, error, status =
      Open3.capture3(clean.merge(env), RbConfig.ruby, *, chdir: dir)
    assert status.success?, [output, error].reject(&:empty?).join("\n")
    output
  end
end
