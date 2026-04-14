# frozen_string_literal: true

require_relative '../test_helper'

FIXTURES = File.expand_path('../fixtures', __dir__)

class ExportTest < Minitest::Test
  def test_single_export_returns_class
    result = import "#{FIXTURES}/single_export"
    assert_equal 'User', result.name
    user = result.new('Alice')
    assert_equal 'Hello, Alice!', user.greet
  end

  def test_hash_export_returns_module_with_methods
    result = import "#{FIXTURES}/hash_export"
    assert_kind_of Package::Exports, result
    assert_equal 10, result.add(3, 7)
    assert_equal 6, result.subtract(10, 4)
    assert_equal '1.0.0', result.version
  end

  def test_hash_export_returns_module_with_constants
    result = import "#{FIXTURES}/hash_export"
    assert_in_delta 3.14159, result::PI
  end

  def test_bare_export_returns_box
    result = import "#{FIXTURES}/bare"
    assert_kind_of Package::Box, result
  end

  def test_bare_export_fetch_constant
    result = import "#{FIXTURES}/bare"
    assert_equal 'hello from bare', result.fetch(:GREETING)
  end

  def test_bare_export_fetch_method
    result = import "#{FIXTURES}/bare"
    assert_equal 42, result.fetch(:helper)
  end

  def test_bare_export_index_lookup
    result = import "#{FIXTURES}/bare"
    assert_equal 'hello from bare', result[:GREETING]
    assert_equal 42, result[:helper]
    assert_nil result[:missing]
  end

  def test_export_raises_when_called_more_than_once
    error = assert_raises(RuntimeError) { import "#{FIXTURES}/double_export" }
    assert_equal 'only one export is allowed per imported file', error.message
  end

  def test_single_export_requires_export_default
    error =
      assert_raises(ArgumentError) { import "#{FIXTURES}/legacy_single_export" }
    assert_equal 'export takes keyword arguments; use export_default for a single export',
                 error.message
  end
end
