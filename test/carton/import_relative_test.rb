# frozen_string_literal: true

require_relative '../test_helper'

class ImportRelativeTest < Minitest::Test
  def test_import_relative_single_export
    result = import_relative '../fixtures/single_export'
    assert_equal 'User', result.name
    user = result.new('Carol')
    assert_equal 'Hello, Carol!', user.greet
  end

  def test_import_relative_bare_math
    result = import_relative '../fixtures/bare_math'
    assert_kind_of Carton::Namespace, result
    assert_equal 8, result.add(3, 5)
    assert_equal 2, result.subtract(5, 3)
    assert_equal '1.0.0', result::VERSION
    assert_in_delta 3.14159, result::PI
  end

  def test_import_relative_destructuring
    import_relative('../fixtures/bare_math') => { add:, PI: pi }
    assert_equal 7, add.(3, 4)
    assert_in_delta 3.14159, pi
  end

  def test_import_relative_nested_with_re_import
    result = import_relative '../fixtures/math_tools/advanced'
    assert_in_delta 314.159, result.circle_area(10)
    assert_equal 25, result.add(10, 15)
    assert_equal '2.0.0', result::VERSION
  end

  def test_import_relative_chained
    result = import_relative '../fixtures/relative_importer'
    assert_equal 'Hello, World!', result.greeting
  end

  def test_import_relative_bare
    result = import_relative '../fixtures/bare'
    assert_kind_of Carton::Namespace, result
    assert_equal 'hello from bare', result.fetch(:GREETING)
  end

  # `json` exists in the stdlib but not next to this file.
  def test_missing_import_relative_raises_instead_of_loading_a_stdlib_feature
    error = assert_raises(LoadError) { import_relative 'json' }
    assert_equal "cannot load such file -- #{__dir__}/json " \
                   "(tried json.rb and json/lib/json.rb in #{__dir__})",
                 error.message
  end

  def test_carton_loads_its_directory_in_one_box
    ledger = import_relative '../fixtures/units/ledger'

    assert_instance_of ledger::Entry, ledger.entry
  end

  # Importing a file inside a Carton would load a second copy of it in its
  # own Box, so its classes would not match the Carton's.
  def test_file_inside_a_carton_cannot_be_imported
    error =
      assert_raises(Carton::ImportError) do
        import_relative '../fixtures/units/ledger/entry'
      end
    assert_match(
      %r{ledger/entry\.rb is inside the Carton .*/ledger\.rb},
      error.message,
    )
  end
end
