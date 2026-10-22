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

  def test_import_by_name_uses_parent_non_gem_load_path
    added = !$LOAD_PATH.include?(FIXTURES_DIR)
    $LOAD_PATH.unshift(FIXTURES_DIR) if added

    result = import 'single_export'
    assert_equal 'User', result.name
  ensure
    $LOAD_PATH.delete(FIXTURES_DIR) if added
  end

  def test_import_by_name_uses_importer_gem_paths_without_copying_them_into_box
    added = !$LOAD_PATH.include?(GEM_LIKE_DIR)
    $LOAD_PATH.unshift(GEM_LIKE_DIR) if added

    result = import "#{FIXTURES_DIR}/load_path_probe"
    refute_includes result::LOAD_PATH_AT_LOAD, GEM_LIKE_DIR
    assert_equal :visible, import('leaked_feature').status
  ensure
    $LOAD_PATH.delete(GEM_LIKE_DIR) if added
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
