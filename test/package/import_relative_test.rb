# frozen_string_literal: true

require_relative '../test_helper'

class ImportRelativeTest < Minitest::Test
  def test_import_relative_single_export
    result = import_relative '../fixtures/single_export'
    assert_equal 'User', result.name
    user = result.new('Carol')
    assert_equal 'Hello, Carol!', user.greet
  end

  def test_import_relative_hash_export
    result = import_relative '../fixtures/hash_export'
    assert_kind_of Package::Exports, result
    assert_equal 8, result.add(3, 5)
    assert_equal 2, result.subtract(5, 3)
    assert_equal '1.0.0', result.version
    assert_in_delta 3.14159, result::PI
  end

  def test_import_relative_destructuring
    import_relative('../fixtures/hash_export') => { add:, PI: pi }
    assert_equal 7, add.(3, 4)
    assert_in_delta 3.14159, pi
  end

  def test_import_relative_nested_with_re_import
    result = import_relative '../fixtures/math_tools/advanced'
    assert_in_delta 314.159, result.circle_area(10)
    assert_equal 25, result.add(10, 15)
    assert_equal '2.0.0', result.version
  end

  def test_import_relative_chained
    result = import_relative '../fixtures/relative_importer'
    assert_equal 'Hello, World!', result.greeting
  end

  def test_import_relative_bare
    result = import_relative '../fixtures/bare'
    assert_kind_of Package::Box, result
    assert_equal 'hello from bare', result.fetch(:GREETING)
  end
end
