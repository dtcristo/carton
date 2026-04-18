# frozen_string_literal: true

require_relative '../test_helper'

FIXTURES_DIR = File.expand_path('../fixtures', __dir__)
GEM_LIKE_DIR =
  File.expand_path('../fixtures/vendor/bundle/fake_gem/lib', __dir__)

class ImportTest < Minitest::Test
  def test_import_absolute_path
    result = import "#{FIXTURES_DIR}/single_export"
    user = result.new('Bob')
    assert_equal 'Hello, Bob!', user.greet
  end

  def test_import_hash_namespace
    result = import "#{FIXTURES_DIR}/hash_export"
    assert_kind_of Carton::Exports, result
    assert_respond_to result, :add
    assert_respond_to result, :subtract
    assert_respond_to result, :version
    assert_equal 3.14159, result::PI
  end

  def test_import_by_name_uses_parent_non_gem_load_path
    added = !$LOAD_PATH.include?(FIXTURES_DIR)
    $LOAD_PATH.unshift(FIXTURES_DIR) if added

    result = import 'single_export'
    assert_equal 'User', result.name
  ensure
    $LOAD_PATH.delete(FIXTURES_DIR) if added
  end

  def test_import_by_name_supports_index_lookup
    added = !$LOAD_PATH.include?(FIXTURES_DIR)
    $LOAD_PATH.unshift(FIXTURES_DIR) if added

    assert_in_delta 3.14159, import('hash_export')[:PI]
  ensure
    $LOAD_PATH.delete(FIXTURES_DIR) if added
  end

  def test_import_by_name_uses_caller_gem_paths_without_copying_them_into_box
    added = !$LOAD_PATH.include?(GEM_LIKE_DIR)
    $LOAD_PATH.unshift(GEM_LIKE_DIR) if added

    result = import "#{FIXTURES_DIR}/bare"
    refute_includes result.load_path, GEM_LIKE_DIR
    assert_equal :visible, import('leaked_feature').status
  ensure
    $LOAD_PATH.delete(GEM_LIKE_DIR) if added
  end

  def test_import_destructuring
    import("#{FIXTURES_DIR}/hash_export") => { add:, subtract:, version: }
    assert_equal 15, add.(10, 5)
    assert_equal 5, subtract.(10, 5)
    assert_equal '1.0.0', version
  end

  def test_import_index_lookup
    result = import "#{FIXTURES_DIR}/hash_export"
    assert_equal '1.0.0', result[:version]
    assert_in_delta 3.14159, result[:PI]
    assert_nil result[:nothing]
    assert_nil result[:missing]
  end

  def test_import_fetch
    result = import "#{FIXTURES_DIR}/hash_export"
    assert_equal '1.0.0', result.fetch(:version)
    assert_in_delta 3.14159, result.fetch(:PI)
    assert_nil result.fetch(:nothing)
  end

  def test_import_fetch_missing_raises
    result = import "#{FIXTURES_DIR}/hash_export"
    error = assert_raises(KeyError) { result.fetch(:missing) }
    assert_match 'missing', error.message
  end

  def test_import_fetch_supports_default_and_block
    result = import "#{FIXTURES_DIR}/hash_export"
    assert_equal 'fallback', result.fetch(:missing, 'fallback')
    assert_equal 'computed missing',
                 result.fetch(:missing) { |key| "computed #{key}" }
  end

  def test_import_fetch_rejects_extra_defaults
    result = import "#{FIXTURES_DIR}/hash_export"
    assert_raises(ArgumentError) { result.fetch(:missing, 'a', 'b') }
  end

  def test_import_fetch_values
    result = import "#{FIXTURES_DIR}/hash_export"
    pi, version = result.fetch_values(:PI, :version)
    assert_in_delta 3.14159, pi
    assert_equal '1.0.0', version
  end

  def test_import_key_queries_and_values_at
    result = import "#{FIXTURES_DIR}/hash_export"
    assert result.key?(:PI)
    assert result.has_key?(:version)
    refute result.key?(:missing)
    assert_equal [3.14159, '1.0.0', nil],
                 result.values_at(:PI, :version, :missing)
  end
end
