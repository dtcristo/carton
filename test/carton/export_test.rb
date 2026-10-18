# frozen_string_literal: true

require_relative '../test_helper'

FIXTURES = File.expand_path('../fixtures', __dir__)

class ExportTest < Minitest::Test
  def test_export_returns_the_value_itself
    pricing = import "#{FIXTURES}/root_module_export"

    assert_instance_of Module, pricing
    assert_equal 'Pricing', pricing.name
  end

  def test_export_of_a_class_returns_the_class
    user = import "#{FIXTURES}/single_export"

    assert_equal 'User', user.name
    assert_equal 'Hello, Alice!', user.new('Alice').greet
  end

  def test_hash_export_returns_the_hash
    result = import "#{FIXTURES}/default_hash_export"

    assert_instance_of Hash, result
    assert_equal 42, result[:answer]
    assert_same result, result[:itself]
  end

  # Keywords are Ruby's own braceless Hash argument, so destructuring needs
  # nothing from Carton.
  def test_keyword_export_is_a_hash
    result = import "#{FIXTURES}/hash_export"

    assert_equal({ PI: 3.14159, nothing: nil, version: '1.0.0' }, result)
    result => { version: }
    assert_equal '1.0.0', version
  end

  def test_nil_and_false_are_exports
    assert_nil import("#{FIXTURES}/default_nil_export")
    assert_equal false, import("#{FIXTURES}/default_false_export")
  end

  def test_export_may_be_called_once
    error =
      assert_raises(Carton::ExportError) do
        import "#{FIXTURES}/repeated_export"
      end
    assert_equal 'export may be called only once per Entrypoint', error.message
  end

  # `def` returns a Symbol, so `export def add` would export :add itself.
  def test_export_rejects_a_symbol
    error =
      assert_raises(Carton::ExportError) { import "#{FIXTURES}/symbol_export" }
    assert_equal 'export takes the value to export, not a name like :add: ' \
                   'export a module, or keywords for a Hash',
                 error.message
  end

  def test_export_requires_a_value
    assert_raises(ArgumentError) { import "#{FIXTURES}/empty_export" }
  end

  def test_root_module_export_keeps_private_constants_private
    pricing = import "#{FIXTURES}/root_module_export"

    assert_in_delta 1.01, pricing::Calculator.new.total
    assert_equal [:Calculator], pricing.constants
    error = assert_raises(NameError) { pricing::Internal }
    assert_match(/private constant/, error.message)
  end

  def test_errors_from_any_box_are_the_importers_classes
    error =
      assert_raises(Carton::ExportError) do
        import "#{FIXTURES}/repeated_export"
      end
    assert_same Carton::ExportError, error.class
    assert_same Carton::ExportError,
                import("#{FIXTURES}/rescues_nested_export_error")
  end

  def test_bare_carton_returns_a_namespace_not_its_box
    result = import "#{FIXTURES}/bare"

    assert_kind_of Carton::Namespace, result
    refute_kind_of Ruby::Box, result
    refute_respond_to result, :eval
    refute_respond_to result, :require
  end

  def test_bare_carton_exposes_constants_and_callable_helpers
    result = import "#{FIXTURES}/bare"

    assert_equal 'hello from bare', result::GREETING
    assert_equal 42, result.helper
    assert_empty result.lookup_calls
  end

  def test_bare_carton_helpers_forward_arguments_keywords_and_block
    result = import "#{FIXTURES}/method_export"

    assert_equal 'HI?', result.decorate('hi', suffix: '?', &:upcase)
    assert_equal 'HI!', result.decorate('hi', &:upcase)
  end

  def test_bare_carton_fetch_constant
    result = import "#{FIXTURES}/bare"
    assert_equal 'hello from bare', result.fetch(:GREETING)
  end

  def test_bare_carton_fetch_method
    result = import "#{FIXTURES}/bare"
    helper = result.fetch(:helper)

    assert_instance_of Method, helper
    assert_equal :helper, helper.name
    assert_equal 42, helper.call
  end

  def test_bare_carton_index_lookup
    result = import "#{FIXTURES}/bare"
    assert_equal 'hello from bare', result[:GREETING]
    assert_equal 42, result[:helper].call
    assert_nil result[:missing]
  end

  def test_bare_carton_lookup_does_not_invoke_helpers
    result = import "#{FIXTURES}/bare"

    result[:effectful_helper]
    result.fetch(:effectful_helper)
    assert_empty result.fetch(:lookup_calls).call
  end

  def test_bare_carton_does_not_evaluate_expressions
    result = import "#{FIXTURES}/bare"

    assert_nil result['1 + 1']
    assert_nil result['nil']
    refute result.key?('1 + 1')
    refute result.key?('nil')
  end

  def test_bare_carton_key_query_does_not_invoke_helpers
    result = import "#{FIXTURES}/bare"

    assert result.key?(:effectful_helper)
    assert_empty result.fetch(:lookup_calls).call
  end

  def test_bare_carton_preserves_nil_and_false_values
    result = import "#{FIXTURES}/bare"

    assert result.key?(:NIL_VALUE)
    assert_nil result.fetch(:NIL_VALUE)
    assert result.key?(:FALSE_VALUE)
    assert_equal false, result.fetch(:FALSE_VALUE)
  end

  def test_bare_carton_helper_errors_propagate_when_called
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

  def test_bare_carton_excludes_runtime_constants_and_box_methods
    result = import "#{FIXTURES}/bare"

    refute result.key?(:Object)
    refute result.key?(:load_path)
    refute result.key?(:require_in_box)
  end

  def test_bare_carton_destructuring_enumerates_its_public_surface
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

  def test_bare_carton_destructuring_does_not_invoke_helpers
    result = import "#{FIXTURES}/bare_deconstruct_error"
    broken_helper = result.deconstruct_keys(nil).fetch(:broken_helper)

    error = assert_raises(NameError) { broken_helper.call }
    assert_equal :MISSING_FROM_DECONSTRUCTION, error.name
  end
end
