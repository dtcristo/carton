# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'

class ImportErrorsTest < Minitest::Test
  def test_missing_name_suggests_import_relative_for_a_sibling
    Dir.mktmpdir do |tmp|
      dir = File.realpath(tmp)
      File.write(File.join(dir, 'sibling.rb'), "export 1\n")
      main = File.join(dir, 'main.rb')
      File.write(main, "import 'sibling'\n")

      error = assert_raises(LoadError) { load main }


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
