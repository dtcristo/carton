# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'

# Exploring a Bare Carton's Carton::Namespace, and the names it cannot take.
class NamespaceTest < Minitest::Test
  def test_inspect_lists_its_names
    namespace = carton("def add(a, b) = a + b\nPI = 3.14\n")

    assert_equal '#<Carton::Namespace add, PI>', namespace.inspect
    assert_equal namespace.inspect, namespace.to_s
  end

  def test_inspect_of_an_empty_bare_carton
    assert_equal '#<Carton::Namespace>', carton("x = 1\n").inspect
  end

  def test_keys_and_to_h_list_helpers_then_constants
    namespace = carton("PI = 3.14\ndef add(a, b) = a + b\n")

    assert_equal %i[add PI], namespace.keys
    hash = namespace.to_h
    assert_equal %i[add PI], hash.keys
    assert_equal 3, hash[:add].call(1, 2)
    assert_in_delta 3.14, hash[:PI]
  end

  def test_helper_shadowing_a_lookup_method_raises
    error = assert_raises(Carton::ExportError) { carton("def fetch = 42\n") }

    assert_equal 'a top-level method named fetch would hide ' \
                   'Carton::Namespace#fetch: rename it, or export a module',
                 error.message
  end

  def test_helper_shadowing_a_module_method_raises
    error = assert_raises(Carton::ExportError) { carton("def name = 'mine'\n") }

    assert_match(/would hide Carton::Namespace#name/, error.message)
  end

  # Constants are capitalized, so they never collide.
  def test_capitalized_names_are_allowed
    namespace = carton("Fetch = 1\nName = 2\n")

    assert_equal 1, namespace::Fetch
    assert_equal 2, namespace::Name
  end

  def test_missing_name_suggests_import_relative_for_a_sibling
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'sibling.rb'), "export 1\n")
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
