# frozen_string_literal: true

require_relative '../test_helper'

class GemspecTest < Minitest::Test
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
  def test_packages_only_library_signatures_and_docs
    root = File.expand_path('../..', __dir__)
    expected =
      Dir.glob(%w[lib/**/*.rb sig/**/*.rbs], base: root) +
        %w[CHANGELOG.md LICENSE.txt README.md]

    assert_equal expected.sort, carton_specification.files.sort
  end

  private

  def carton_specification
    path = File.expand_path('../../carton.gemspec', __dir__)
    Gem::Specification.load(path)
  end
end
