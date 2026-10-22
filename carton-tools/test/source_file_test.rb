# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'

class SourceFileTest < Minitest::Test
  SourceFile = Carton::Tools.const_get(:SourceFile)

  def test_finds_imports_with_their_constants
    file = parse(<<~RUBY)
      Billing = import 'billing'
      module App
        MathTools = import_relative('math')
      end
      tools = import "\#{Dir.pwd}/tools"
    RUBY

    assert_equal(
      [
        [:import, 'billing', 'Billing'],
        [:import_relative, 'math', 'App::MathTools'],
        [:import, nil, nil],
      ],
      file.imports.map { |call| [call.kind, call.path, call.constant] },
    )
  end

  def test_imports_in_methods_and_blocks_are_lazy
    file = parse(<<~RUBY)
      import 'eager'
      class Thing
        import 'in_class_body'
        def self.later = import('in_method')
      end
      -> { import 'in_lambda' }
      [1].each { import 'in_block' }
    RUBY

    assert_equal(
      {
        'eager' => false,
        'in_class_body' => false,
        'in_method' => true,
        'in_lambda' => true,
        'in_block' => true,
      },
      file.imports.to_h { |call| [call.path, call.lazy] },
    )
  end

  def test_finds_requires
    file = parse("require 'json'\nrequire_relative 'billing/tax'\n")

    assert_equal(
      [[:require, 'json'], [:require_relative, 'billing/tax']],
      file.requires.map { |call| [call.kind, call.path] },
    )
  end

  def test_reads_an_exported_constant
    file = parse("module Billing; end\nexport Billing\n")

    assert_equal 'Billing', file.exports.first.value
    assert_nil file.exports.first.keys
    assert_equal({ 'Billing' => :module }, file.definitions)
  end

  def test_reads_keyword_and_hash_exports
    keywords, hash, dynamic =
      parse(
        "export VERSION: '1.0', answer: 42\nexport({ a: 1 })\nexport **x\n",
      ).exports

    assert_equal(
      { 'VERSION' => '::String', 'answer' => '::Integer' },
      keywords.keys,
    )
    assert_equal({ 'a' => '::Integer' }, hash.keys)
    assert_nil dynamic.keys
    assert_nil keywords.value
  end

  def test_marks_symbol_exports
    def_export, symbol, value =
      parse("export def add = 1\nexport :x\nexport 1\n").exports

    assert def_export.symbol
    assert symbol.symbol
    refute value.symbol
  end

  def test_ignores_exports_inside_methods_and_namespaces
    file = parse("def setup = export(1)\nmodule M\n  export 2\nend\n")

    assert_empty file.exports
  end

  def test_types_literal_constants
    file = parse(<<~RUBY)
      NAME = 'x'.freeze
      COUNT = 1
      RATIO = 0.5
      FLAGS = [true]
      OTHER = compute
    RUBY

    assert_equal(
      {
        'NAME' => '::String',
        'COUNT' => '::Integer',
        'RATIO' => '::Float',
        'FLAGS' => '::Array[untyped]',
        'OTHER' => 'untyped',
      },
      file.constants,
    )
  end

  def test_records_how_bound_names_are_used
    file = parse(<<~RUBY)
      MathTools = import 'math'
      m = import 'math'
      MathTools.add(1, 2)
      MathTools::PI
      MathTools.fetch(:a)
      MathTools.fetch(:b, nil)
      MathTools.values_at(:c, :d)
      m.sub
      use(MathTools)
      MathTools => { e:, **rest }
    RUBY

    assert_equal [nil, 'm'], file.imports.map(&:local)
    uses =
      file.references.reject do |ref|
        ref.name.include?('::') || %w[rest e].include?(ref.name)
      end
    expected = [
      ['MathTools', :call, 'add'],
      ['MathTools', :const, 'PI'],
      ['MathTools', :fetch, 'a'],
      ['MathTools', :lookup, 'b'],
      ['MathTools', :lookup, 'c'],
      ['MathTools', :lookup, 'd'],
      ['m', :call, 'sub'],
      ['MathTools', :value, nil],
      ['MathTools', :fetch, 'e'],
      ['MathTools', :value, nil],
    ]
    assert_equal(expected, uses.map { |ref| [ref.name, ref.kind, ref.member] })
  end

  def test_records_patterns_matched_against_an_import
    file = parse("import('math') => { add:, **rest }\n")

    pattern = file.imports.first.pattern
    assert_equal :fetch, pattern.kind
    assert_equal %w[add **], pattern.keys
  end

  def test_class_definitions_are_not_uses
    file = parse("class Billing::Invoice; end\n")

    assert_empty file.references
  end

  def test_records_private_constants
    file = parse(<<~RUBY)
      module Billing
        private_constant :Tax
      end
      Billing.private_constant :Rate
    RUBY

    assert_equal %w[Billing::Tax Billing::Rate], file.private_constants
  end

  def test_dynamic_marker_on_the_line_or_above
    file =
      parse(
        "import(x) # carton:dynamic\n# carton:dynamic\nimport(y)\nimport(z)\n",
      )

    assert file.dynamic_marker?(1)
    assert file.dynamic_marker?(3)
    refute file.dynamic_marker?(4)
  end

  def test_records_parse_errors
    file = parse("def broken(\n")

    refute_empty file.errors
    assert_equal 1, file.errors.first.first.line
    assert_equal 12, file.errors.first.first.column
  end

  # Columns count characters from 1, not bytes.
  def test_records_character_columns
    file = parse("é = 1; import 'x'\nexport(é)\n")

    assert_equal [1, 8], [file.imports.first.line, file.imports.first.column]
    assert_equal [2, 1], [file.exports.first.line, file.exports.first.column]
  end

  private

  def parse(source)
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'source.rb')
      File.write(path, source)
      SourceFile.parse(path)
    end
  end
end
