# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'

FIXTURES = File.expand_path('../fixtures', __dir__)

class ExportTest < Minitest::Test
  def test_export_returns_the_value_itself
    pricing = import "#{FIXTURES}/root_module_export"

    assert_instance_of Module, pricing
    assert_equal 'Pricing', pricing.name
  end

  def test_export_of_a_class_returns_the_class
    user = import "#{FIXTURES}/single_export"

    assert_equal 'User', user.name
    assert_equal 'Hello, Alice!', user.new('Alice').greet
  end

  def test_hash_export_returns_the_hash
    result = import "#{FIXTURES}/default_hash_export"

    assert_instance_of Hash, result
    assert_equal 42, result[:answer]
    assert_same result, result[:itself]
  end

  # Keywords are Ruby's own braceless Hash argument, so destructuring needs
  # nothing from Carton.
  def test_keyword_export_is_a_hash
    result = import "#{FIXTURES}/hash_export"

    assert_equal({ PI: 3.14159, nothing: nil, version: '1.0.0' }, result)
    result => { version: }
    assert_equal '1.0.0', version
  end

  def test_nil_and_false_are_exports
    assert_nil import("#{FIXTURES}/default_nil_export")
    assert_equal false, import("#{FIXTURES}/default_false_export")
  end

  def test_export_may_be_called_once
    error =
      assert_raises(Carton::ExportError) do
        import "#{FIXTURES}/repeated_export"
      end
    assert_equal 'export may be called only once per Entrypoint', error.message
  end

  # `def` returns a Symbol, so `export def add` would export :add itself.
  def test_export_rejects_a_symbol
    error =
      assert_raises(Carton::ExportError) { import "#{FIXTURES}/symbol_export" }
    assert_equal 'export takes the value to export, not a name like :add: ' \
                   'export a module, or keywords for a Hash',
                 error.message
  end

  # A method that calls `export` after the Import finishes declares
  # nothing, as `export` outside an Entrypoint does.
  def test_export_is_inert_after_the_import_finishes
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'late.rb')
      File.write(path, <<~RUBY)
        module Late
          def self.export_again = export(:ignored.to_s)
        end
        export Late
      RUBY

      late = import path

      assert_equal 'ignored', late.export_again
      assert_same late, import(path)
    end
  end

  def test_export_requires_a_value
    assert_raises(ArgumentError) { import "#{FIXTURES}/empty_export" }
  end

  def test_root_module_export_keeps_private_constants_private
    pricing = import "#{FIXTURES}/root_module_export"

    assert_in_delta 1.01, pricing::Calculator.new.total
    assert_equal [:Calculator], pricing.constants
    error = assert_raises(NameError) { pricing::Internal }
    assert_match(/private constant/, error.message)
  end

  def test_errors_from_any_box_are_the_importers_classes
    error =
      assert_raises(Carton::ExportError) do
        import "#{FIXTURES}/repeated_export"
      end
    assert_same Carton::ExportError, error.class
    assert_same Carton::ExportError,
                import("#{FIXTURES}/rescues_nested_export_error")
  end

  def test_entrypoint_must_export_explicitly
    error =
      assert_raises(Carton::ExportError) { import "#{FIXTURES}/no_export" }

    assert_match(/no_export\.rb.*must call export/, error.message)
  end

  def test_missing_export_is_not_cached
    Dir.mktmpdir do |dir|
      entry = File.join(dir, 'retry.rb')
      File.write(entry, "VALUE = 1\n")
      assert_raises(Carton::ExportError) { import entry }

      File.write(entry, "export 42\n")
      assert_equal 42, import(entry)
    end
  end

  def test_only_the_imported_entrypoints_export_counts
    Dir.mktmpdir do |dir|
      File.write(File.join(dir, 'dependency.rb'), "export 42\n")
      entry = File.join(dir, 'entry.rb')
      File.write(entry, "require_relative 'dependency'\n")

      assert_raises(Carton::ExportError) { import entry }
    end
  end

  def test_legacy_adapter_keeps_its_export_when_required_code_adds_export
    Dir.mktmpdir do |dir|
      dependency = File.join(dir, 'foo.rb')
      source = "module Foo; def self.label = 'foo'; end\n"
      File.write(dependency, source)
      File.write(
        File.join(dir, 'before.rb'),
        "require_relative 'foo'\nexport Foo\n",
      )
      assert_equal 'foo', import(File.join(dir, 'before')).label

      File.write(dependency, "#{source}export Foo\n")
      File.write(
        File.join(dir, 'after.rb'),
        "require_relative 'foo'\nexport Foo\n",
      )
      assert_equal 'foo', import(File.join(dir, 'after')).label
    end
  end
end
