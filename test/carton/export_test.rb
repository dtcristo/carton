# frozen_string_literal: true

require_relative '../test_helper'

FIXTURES = File.expand_path('../fixtures', __dir__)

class ExportTest < Minitest::Test
  def test_constant_symbol_exports_the_class_itself
    result = import "#{FIXTURES}/single_export"

    assert_kind_of Carton::Exports, result
    assert_equal 'User', result::User.name
    assert_equal 'Hello, Alice!', result::User.new('Alice').greet
  end

  def test_root_module_export_keeps_private_constants_private
    pricing = import("#{FIXTURES}/root_module_export")::Pricing

    assert_in_delta 1.01, pricing::Calculator.new.total
    assert_equal [:Calculator], pricing.constants
    error = assert_raises(NameError) { pricing::Internal }
    assert_match(/private constant/, error.message)
  end

  def test_export_calls_accumulate_into_one_namespace
    result = import "#{FIXTURES}/multiple_export"

    assert_equal 'Widget', result::Widget.name
    assert_equal 9, result.area(3)
    assert_equal '1.0.0', result::VERSION
    assert_equal 'widgets', result.label
    assert_equal %i[VERSION Widget area label],
                 result.deconstruct_keys(nil).keys.sort
  end

  def test_export_rejects_a_name_repeated_across_calls
    error =
      assert_raises(ArgumentError) { import "#{FIXTURES}/repeated_name_export" }
    assert_equal 'export name given more than once: add', error.message
  end

  def test_constant_symbol_export_missing_constant_raises_name_error
    error =
      assert_raises(NameError) { import "#{FIXTURES}/missing_constant_export" }
    assert_equal :Missing, error.name
  end

  def test_export_with_nil_and_false_values
    result = import "#{FIXTURES}/hash_export"

    assert_nil result.nothing
    assert result.key?(:nothing)
  end

  def test_export_namespace_does_not_expose_its_stored_values
    result = import "#{FIXTURES}/export_return"

    assert_equal '1.0.0', result.version
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

  def test_symbol_export_lookups_return_method_objects
    result = import "#{FIXTURES}/hash_export"

    assert_instance_of Method, result[:add]
    assert_same result[:add], result.fetch(:add)
    assert_equal :add, result[:add].name
    assert_equal 5, result[:add].call(2, 3)
    result => { add: }
    assert_same result[:add], add
  end

  def test_symbol_export_forwards_arguments_keywords_and_block
    result = import "#{FIXTURES}/method_export"

    assert_equal 'HI?', result.decorate('hi', suffix: '?', &:upcase)
    assert_equal 'HI!', result.decorate('hi', &:upcase)
  end

  def test_callable_keyword_value_is_not_invoked
    result = import "#{FIXTURES}/method_export"
    handler = result.handler

    assert_instance_of Proc, handler
    assert_same handler, result[:handler]
    assert_equal 6, handler.call(3)
    assert_raises(ArgumentError) { result.handler(3) }
  end

  def test_symbol_export_missing_method_raises_name_error
    error =
      assert_raises(NameError) { import "#{FIXTURES}/missing_method_export" }
    assert_equal :missing, error.name
  end

  def test_export_rejects_duplicate_names
    error =
      assert_raises(ArgumentError) do
        import "#{FIXTURES}/duplicate_name_export"
      end
    assert_equal 'export name given more than once: add', error.message
  end

  def test_export_requires_names_or_values
    error = assert_raises(ArgumentError) { import "#{FIXTURES}/empty_export" }
    assert_equal 'export takes Symbols naming methods or constants, and keyword values',
                 error.message
  end

  def test_bare_export_returns_exports_not_its_box
    result = import "#{FIXTURES}/bare"

    assert_kind_of Carton::Exports, result
    refute_kind_of Ruby::Box, result
    refute_respond_to result, :eval
    refute_respond_to result, :require
  end

  def test_bare_export_exposes_constants_and_callable_helpers
    result = import "#{FIXTURES}/bare"

    assert_equal 'hello from bare', result::GREETING
    assert_equal 42, result.helper
    assert_empty result.lookup_calls
  end

  def test_bare_export_fetch_constant
    result = import "#{FIXTURES}/bare"
    assert_equal 'hello from bare', result.fetch(:GREETING)
  end

  def test_bare_export_fetch_method
    result = import "#{FIXTURES}/bare"
    helper = result.fetch(:helper)

    assert_instance_of Method, helper
    assert_equal :helper, helper.name
    assert_equal 42, helper.call
  end

  def test_bare_export_index_lookup
    result = import "#{FIXTURES}/bare"
    assert_equal 'hello from bare', result[:GREETING]
    assert_equal 42, result[:helper].call
    assert_nil result[:missing]
  end

  def test_bare_export_lookup_does_not_invoke_helpers
    result = import "#{FIXTURES}/bare"

    result[:effectful_helper]
    result.fetch(:effectful_helper)
    assert_empty result.fetch(:lookup_calls).call
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
    assert_empty result.fetch(:lookup_calls).call
  end

  def test_bare_export_preserves_nil_and_false_values
    result = import "#{FIXTURES}/bare"

    assert result.key?(:NIL_VALUE)
    assert_nil result.fetch(:NIL_VALUE)
    assert result.key?(:FALSE_VALUE)
    assert_equal false, result.fetch(:FALSE_VALUE)
  end

  def test_bare_export_helper_errors_propagate_when_called
    result = import "#{FIXTURES}/bare"

    name_error =
      assert_raises(NameError) { result.fetch(:raises_name_error).call }
    assert_equal :MISSING_FROM_HELPER, name_error.name

    method_error =
      assert_raises(NoMethodError) do
        result.fetch(:raises_no_method_error).call
      end
    assert_equal :missing_from_helper, method_error.name
  end

  def test_bare_export_excludes_runtime_constants_and_box_methods
    result = import "#{FIXTURES}/bare"

    refute result.key?(:Object)
    refute result.key?(:load_path)
    refute result.key?(:require_in_box)
  end

  def test_bare_export_destructuring_enumerates_its_public_surface
    import("#{FIXTURES}/bare_deconstruct") => {
      BARE_LABEL: label, effectful_helper:, **rest
    }

    assert_equal 'bare', label
    assert_instance_of Method, effectful_helper
    assert_equal %i[DECONSTRUCTION_CALLS helper], rest.keys.sort
    assert_empty rest.fetch(:DECONSTRUCTION_CALLS)
    assert_equal :effect, effectful_helper.call
    assert_equal 42, rest.fetch(:helper).call
  end

  def test_bare_export_destructuring_does_not_invoke_helpers
    result = import "#{FIXTURES}/bare_deconstruct_error"
    broken_helper = result.deconstruct_keys(nil).fetch(:broken_helper)

    error = assert_raises(NameError) { broken_helper.call }
    assert_equal :MISSING_FROM_DECONSTRUCTION, error.name
  end

  def test_export_rejects_a_module_argument
    error =
      assert_raises(ArgumentError) { import "#{FIXTURES}/legacy_single_export" }
    assert_equal 'export takes Symbols naming methods or constants, and keyword values',
                 error.message
  end
end
