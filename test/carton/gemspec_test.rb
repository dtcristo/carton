# frozen_string_literal: true

require_relative '../test_helper'

class GemspecTest < Minitest::Test
  def test_required_ruby_version_accepts_4_0_6_and_later
    requirement = carton_specification.required_ruby_version

    assert requirement.satisfied_by?(Gem::Version.new('4.0.6'))
    assert requirement.satisfied_by?(Gem::Version.new('4.0.7'))
    assert requirement.satisfied_by?(Gem::Version.new('4.1.0'))
  end

  def test_required_ruby_version_rejects_ruby_older_than_4_0_6
    requirement = carton_specification.required_ruby_version

    refute requirement.satisfied_by?(Gem::Version.new('4.0.5'))
    refute requirement.satisfied_by?(Gem::Version.new('4.0.2'))
    refute requirement.satisfied_by?(Gem::Version.new('3.4.0'))
  end

  def test_description_names_ruby_4_0_6_baseline
    assert_includes carton_specification.description, 'Ruby 4.0.6'
  end

  private

  def carton_specification
    path = File.expand_path('../../carton.gemspec', __dir__)
    Gem::Specification.load(path)
  end
end
