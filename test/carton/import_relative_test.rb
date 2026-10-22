# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class ImportRelativeTest < Minitest::Test
  def test_import_relative_single_export
    result = import_relative '../fixtures/single_export'
    assert_equal 'User', result.name
    user = result.new('Carol')
    assert_equal 'Hello, Carol!', user.greet
  end

  def test_import_relative_module
    result = import_relative '../fixtures/math_export'
    assert_instance_of Module, result
    assert_equal 8, result.add(3, 5)
    assert_equal 2, result.subtract(5, 3)
    assert_equal '1.0.0', result::VERSION
    assert_in_delta 3.14159, result::PI
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

  # A script run by relative path, as in `ruby main.rb`, still resolves
  # against its own directory after it changes directory.
  def test_resolves_against_the_calling_file_after_chdir
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'sibling.rb'), "export :ok.to_s\n")
      File.write(File.join(dir, 'main.rb'), <<~RUBY)
        require 'carton'
        Dir.chdir('/')
        puts import_relative('sibling')
      RUBY

      output, error, status =
        Open3.capture3(
          { 'RUBY_BOX' => '1', 'RUBYOPT' => nil, 'RUBYLIB' => nil },
          RbConfig.ruby,
          '-I',
          File.expand_path('../../lib', __dir__),
          'main.rb',
          chdir: dir,
        )

      assert status.success?, error
      assert_equal "ok\n", output
    end
  end

  # Like `require_relative`, `eval` code has no file to resolve against.
  def test_raises_inside_eval
    error = assert_raises(LoadError) { eval("import_relative 'x'") }
    assert_equal 'cannot infer basepath', error.message
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
