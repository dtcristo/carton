# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'

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
    result = import "#{FIXTURES_DIR}/bare_math"
    assert_kind_of Carton::Namespace, result
    assert_respond_to result, :add
    assert_respond_to result, :subtract
    assert_equal '1.0.0', result::VERSION
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

    assert_in_delta 3.14159, import('bare_math')[:PI]
  ensure
    $LOAD_PATH.delete(FIXTURES_DIR) if added
  end

  def test_import_by_name_uses_caller_gem_paths_without_copying_them_into_box
    added = !$LOAD_PATH.include?(GEM_LIKE_DIR)
    $LOAD_PATH.unshift(GEM_LIKE_DIR) if added

    result = import "#{FIXTURES_DIR}/load_path_probe"
    refute_includes result::LOAD_PATH_AT_LOAD, GEM_LIKE_DIR
    assert_equal :visible, import('leaked_feature').status
  ensure
    $LOAD_PATH.delete(GEM_LIKE_DIR) if added
  end

  def test_import_destructuring
    import("#{FIXTURES_DIR}/bare_math") => { add:, subtract:, VERSION: version }
    assert_equal 15, add.(10, 5)
    assert_equal 5, subtract.(10, 5)
    assert_equal '1.0.0', version
  end

  def test_import_destructuring_collects_remaining_named_exports
    import("#{FIXTURES_DIR}/bare_math") => { VERSION: version, **rest }

    assert_equal '1.0.0', version
    assert_equal %i[NOTHING PI add subtract], rest.keys.sort
    assert_in_delta 3.14159, rest.fetch(:PI)
  end

  def test_import_destructuring_can_collect_an_empty_rest
    import("#{FIXTURES_DIR}/bare_math") => {
      add:, subtract:, PI: pi, NOTHING: nothing, VERSION: version, **rest
    }

    assert_empty rest
  end

  def test_import_destructuring_rejects_an_unknown_key
    result = import "#{FIXTURES_DIR}/bare_math"

    assert_raises(NoMatchingPatternKeyError) { result => { missing: } }
  end

  def test_import_index_lookup
    result = import "#{FIXTURES_DIR}/bare_math"
    assert_equal '1.0.0', result[:VERSION]
    assert_in_delta 3.14159, result[:PI]
    assert_nil result[:NOTHING]
    assert_nil result[:missing]
  end

  def test_import_fetch
    result = import "#{FIXTURES_DIR}/bare_math"
    assert_equal '1.0.0', result.fetch(:VERSION)
    assert_in_delta 3.14159, result.fetch(:PI)
    assert_nil result.fetch(:NOTHING)
  end

  def test_import_fetch_missing_raises
    result = import "#{FIXTURES_DIR}/bare_math"
    error = assert_raises(KeyError) { result.fetch(:missing) }
    assert_match 'missing', error.message
  end

  def test_import_fetch_supports_default_and_block
    result = import "#{FIXTURES_DIR}/bare_math"
    assert_equal 'fallback', result.fetch(:missing, 'fallback')
    assert_equal 'computed missing',
                 result.fetch(:missing) { |key| "computed #{key}" }
  end

  def test_import_fetch_rejects_extra_defaults
    result = import "#{FIXTURES_DIR}/bare_math"
    assert_raises(ArgumentError) { result.fetch(:missing, 'a', 'b') }
  end

  def test_import_fetch_values
    result = import "#{FIXTURES_DIR}/bare_math"
    pi, version = result.fetch_values(:PI, :VERSION)
    assert_in_delta 3.14159, pi
    assert_equal '1.0.0', version
  end

  def test_import_key_queries_and_values_at
    result = import "#{FIXTURES_DIR}/bare_math"
    assert result.key?(:PI)
    assert result.has_key?(:VERSION)
    refute result.key?(:missing)
    assert_equal [3.14159, '1.0.0', nil],
                 result.values_at(:PI, :VERSION, :missing)
  end

  def test_import_missing_absolute_path_raises_load_error
    error = assert_raises(LoadError) { import "#{FIXTURES_DIR}/nope" }
    assert_equal "cannot load such file -- #{FIXTURES_DIR}/nope " \
                   "(tried nope.rb and nope/lib/nope.rb in #{FIXTURES_DIR})",
                 error.message
  end

  def test_import_missing_name_raises_load_error
    assert_raises(LoadError) { import 'carton_missing_feature_name' }
  end

  # Nested `require` inside the Imported Carton uses the load-path entry it
  # was found through, even when that entry is a symlink or relative.
  def test_import_through_symlinked_and_relative_load_path_entries
    Dir.mktmpdir do |dir|
      real = File.join(dir, 'real')
      Dir.mkdir(real)
      File.write(
        "#{real}/needs_dep.rb",
        "require 'nested_dep'\nexport value: NestedDep\n",
      )
      File.write("#{real}/nested_dep.rb", "NestedDep = :nested\n")
      File.symlink(real, File.join(dir, 'linked'))

      with_load_path(File.join(dir, 'linked')) do
        assert_equal :nested, import('needs_dep')[:value]
      end
      Dir.chdir(dir) do
        with_load_path('real') do
          assert_equal :nested, import("#{real}/needs_dep")[:value]
        end
      end
    end
  end

  private

  def with_load_path(entry)
    $LOAD_PATH.unshift(entry)
    yield
  ensure
    $LOAD_PATH.delete(entry)
  end
end
