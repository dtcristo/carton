# frozen_string_literal: true

unless Ruby::Box.enabled? &&
         Gem::Version.new(RUBY_VERSION) >= Gem::Version.new('4.0.7')
  raise 'Run with RUBY_BOX=1 on Ruby 4.0.7+'
end

module Assertions
  def assert(condition, message = 'Assertion failed')
    raise message unless condition
  end

  def equal(expected, actual)
    assert(
      expected == actual,
      "Expected #{expected.inspect}, got #{actual.inspect}",
    )
  end
end
extend Assertions
