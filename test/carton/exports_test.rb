# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'

# Exploring an Export Namespace, and the names it cannot take.
class ExportsTest < Minitest::Test
  def test_inspect_lists_exported_names
    exports =
      carton("export def add(a, b) = a + b\nexport PI: 3.14, version: '1'\n")

    assert_equal '#<Carton::Exports add, PI, version>', exports.inspect
    assert_equal exports.inspect, exports.to_s
  end

  def test_inspect_of_an_empty_bare_carton
    assert_equal '#<Carton::Exports>', carton("x = 1\n").inspect
  end

  def test_keys_and_to_h_follow_export_order
    exports = carton("export def add(a, b) = a + b\nexport PI: 3.14\n")

    assert_equal %i[add PI], exports.keys
    hash = exports.to_h
    assert_equal %i[add PI], hash.keys
    assert_equal 3, hash[:add].call(1, 2)
    assert_in_delta 3.14, hash[:PI]
  end

  def test_bare_carton_keys_list_its_surface
    exports = carton("LIMIT = 3\ndef helper = :ok\n")

    assert_equal %i[LIMIT helper], exports.keys.sort
  end

  def test_export_shadowing_a_lookup_method_raises
    error = assert_raises(Carton::ExportError) { carton("export fetch: 42\n") }

    assert_equal 'export name fetch would hide Carton::Exports#fetch: ' \
                   'rename it, or export it inside a Default Export',
                 error.message
  end

  def test_export_shadowing_a_module_method_raises
    error =
      assert_raises(Carton::ExportError) do
        carton("export def name = 'mine'\n")
      end

    assert_match(
      /\Aexport name name would hide Carton::Exports#name/,
      error.message,
    )
  end

  def test_bare_helper_shadowing_a_method_raises
    error = assert_raises(Carton::ExportError) { carton("def keys = []\n") }

    assert_match(/\Aexport name keys would hide/, error.message)
  end

  # Capitalized names become constants, so they never collide.
  def test_capitalized_names_are_allowed
    exports = carton("export Fetch: 1, Name: 2\n")

    assert_equal 1, exports::Fetch
    assert_equal 2, exports::Name
  end

  def test_missing_name_suggests_import_relative_for_a_sibling
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'sibling.rb'), "export_default 1\n")
      main = File.join(dir, 'main.rb')

      error =
        assert_raises(LoadError) do
          eval("import 'sibling'", TOPLEVEL_BINDING, main)
        end

      assert_equal 'cannot load such file -- sibling: import searches ' \
                     '$LOAD_PATH, like require; use import_relative "sibling" ' \
                     "for #{File.join(dir, 'sibling.rb')}",
                   error.message
    end
  end

  def test_missing_name_without_a_sibling_explains_the_search
    error = assert_raises(LoadError) { import 'carton_missing_feature_name' }

    assert_equal 'cannot load such file -- carton_missing_feature_name: ' \
                   'import searches $LOAD_PATH, like require',
                 error.message
  end

  # A failing require inside the Carton keeps Ruby's own error.
  def test_load_error_inside_a_carton_is_unchanged
    error =
      assert_raises(LoadError) { carton("require 'carton_missing_inner'\n") }

    assert_equal 'cannot load such file -- carton_missing_inner', error.message
  end

  private

  def carton(source)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'carton.rb')
      File.write(path, source)
      import path
    end
  end
end
