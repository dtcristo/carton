# frozen_string_literal: true

require_relative '../test_helper'

class KernelVisibilityTest < Minitest::Test
  METHODS = %i[import import_relative export].freeze

  def test_methods_are_private_kernel_methods
    METHODS.each do |name|
      assert Kernel.private_method_defined?(name), name
      refute Kernel.public_method_defined?(name), name
    end
  end

  def test_objects_do_not_respond_to_methods
    METHODS.each do |name|
      refute_respond_to Object.new, name
      refute_respond_to 'str', name
      refute_respond_to 1, name
    end
  end

  def test_explicit_receiver_raises_no_method_error
    METHODS.each do |name|
      error = assert_raises(NoMethodError) { 'str'.public_send(name, 'x') }
      assert_match(/private method/, error.message)
    end
  end

  def test_available_privately_at_top_level
    METHODS.each do |name|
      assert_respond_to TOPLEVEL_BINDING.receiver, name, include_all: true
    end
  end

  def test_import_relative_inside_methods_of_imported_carton
    result = import_relative '../fixtures/method_importer'

    assert_equal 5, result[:add].call(2, 3)
    assert_in_delta 3.14159, result[:PI], 0.001
  end
end
