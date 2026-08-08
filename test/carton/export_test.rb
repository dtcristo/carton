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
    assert_kind_of Carton::Exports, result
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
    assert_kind_of Carton::Box, result
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

  def test_bare_export_does_not_evaluate_expressions
    result = import "#{FIXTURES}/bare"

    assert_nil result['1 + 1']
    assert_nil result['nil']
    refute result.key?('1 + 1')
    refute result.key?('nil')
  end

  def test_bare_export_key_query_does_not_invoke_helpers
    result = import "#{FIXTURES}/bare"

    assert result.key?(:effectful_helper)
    assert_empty result.fetch(:lookup_calls)
  end

  def test_bare_export_preserves_nil_and_false_values
    result = import "#{FIXTURES}/bare"

    assert result.key?(:NIL_VALUE)
    assert_nil result.fetch(:NIL_VALUE)
    assert result.key?(:FALSE_VALUE)
    assert_equal false, result.fetch(:FALSE_VALUE)
  end

  def test_bare_export_propagates_helper_name_errors
    result = import "#{FIXTURES}/bare"

    name_error = assert_raises(NameError) { result.fetch(:raises_name_error) }
    assert_equal :MISSING_FROM_HELPER, name_error.name

    method_error =
      assert_raises(NoMethodError) { result.fetch(:raises_no_method_error) }
    assert_equal :missing_from_helper, method_error.name
  end

  def test_bare_export_excludes_runtime_constants_and_box_methods
    result = import "#{FIXTURES}/bare"

    refute result.key?(:Object)
    refute result.key?(:load_path)
    refute result.key?(:require_in_box)
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
