# frozen_string_literal: true

require_relative '../test_helper'

class IntegrationTest < Minitest::Test
  FIXTURES = File.expand_path('../fixtures', __dir__)

  def test_nested_import_relative_chain
    # advanced.rb uses import_relative to load basic.rb, re-exports add
    result = import_relative '../fixtures/math_tools/advanced'
    assert_in_delta 314.159, result.circle_area(10)
    assert_equal 20, result.add(8, 12)
    assert_equal '2.0.0', result.version
  end

  def test_single_export_isolation
    # Each import creates a fresh box — no leaking between imports
    a = import "#{FIXTURES}/single_export"
    b = import "#{FIXTURES}/single_export"
    refute_same a, b
    assert_equal a.name, b.name
  end

  def test_hash_export_isolation
    a = import "#{FIXTURES}/hash_export"
    b = import "#{FIXTURES}/hash_export"
    refute_same a, b
  end

  def test_mixed_import_styles
    # Use import with absolute path
    user_class = import "#{FIXTURES}/single_export"

    # Use import_relative
    math = import_relative '../fixtures/hash_export'

    # Both work correctly in the same context
    alice = user_class.new('Alice')
    assert_equal 'Hello, Alice!', alice.greet
    assert_equal 10, math.add(3, 7)
  end

  def test_destructuring_with_rename
    import("#{FIXTURES}/hash_export") => { add: sum }
    assert_equal 42, sum.(20, 22)
  end

  def test_re_export_through_chain
    # advanced.rb imports basic.rb's add and re-exports it
    result = import_relative '../fixtures/math_tools/advanced'
    assert_equal 100, result.add(40, 60)
  end

  def test_import_relative_from_within_box
    # relative_importer.rb uses import_relative internally to load single_export.rb
    result = import_relative '../fixtures/relative_importer'
    assert_equal 'Hello, World!', result.greeting
  end
end
