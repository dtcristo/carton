# frozen_string_literal: true

require_relative '../test_helper'
require 'carton/cli'
require 'tmpdir'

class SourceFileTest < Minitest::Test
  SourceFile = Carton.const_get(:SourceFile)

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
        %w[import billing Billing],
        %w[import_relative math App::MathTools],
        ['import', nil, nil],
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
      [%w[require json], %w[require_relative billing/tax]],
      file.requires.map { |call| [call.kind, call.path] },
    )
  end

  def test_reads_named_exports
    file = parse(<<~RUBY)
      export def add(a, b) = a + b
      export :PI, :helper, VERSION: '1.0', answer: 42
    RUBY

    first, second = file.exports
    assert_equal ['add'], first.names
    assert_equal %w[PI helper], second.names
    assert_equal(
      { 'VERSION' => '::String', 'answer' => '::Integer' },
      second.values,
    )
    refute second.dynamic
  end

  def test_reads_default_export_constant
    file = parse("module Billing; end\nexport_default Billing\n")

    assert_equal 'Billing', file.exports.first.default
    assert_equal({ 'Billing' => :module }, file.definitions)
  end

  def test_ignores_exports_inside_methods_and_namespaces
    file = parse("def setup = export(:x)\nmodule M\n  export :y\nend\n")

    assert_empty file.exports
  end

  def test_types_methods_from_parameters
    file = parse(<<~RUBY)
      def plain(a, b = 1, *rest, c, key:, opt: 2, **opts, &block) = nil
      def forward(...) = nil
      def none = nil
    RUBY

    assert_equal '(untyped a, ?untyped b, *untyped rest, untyped c, ' \
                   'key: untyped, ?opt: untyped, **untyped opts) ' \
                   '?{ (?) -> untyped } -> untyped',
                 file.methods['plain'].type
    assert_equal '(*untyped, **untyped) ?{ (?) -> untyped } -> untyped',
                 file.methods['forward'].type
    assert_equal '() -> untyped', file.methods['none'].type
  end

  def test_reads_rbs_inline_annotations
    file = parse(<<~RUBY)
      #: (Integer amount) -> String
      export def label(amount) = amount.to_s
      RATE = compute #: Float
    RUBY

    assert_equal '(Integer amount) -> String', file.methods['label'].type
    assert_equal 'Float', file.constants['RATE']
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

  def test_records_parse_errors
    file = parse("def broken(\n")

    refute_empty file.errors
    assert_equal 1, file.errors.first.first
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
