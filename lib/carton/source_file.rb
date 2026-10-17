# frozen_string_literal: true

require 'prism'

module Carton
  # What one Ruby file imports, requires, exports, and defines at top level,
  # read with Prism without running it. `carton rbs` and `carton check` build
  # on these facts.
  class SourceFile
    # An `import`, `import_relative`, `require`, or `require_relative` call.
    # `path` is nil when the argument is not a string literal. `lazy` is true
    # inside a method, block, or lambda, which may run after loading.
    # `constant` names the constant the call's result is assigned to.
    Call =
      Data.define(:kind, :path, :file, :line, :lazy, :constant) do
        def relative? = kind.end_with?('_relative')
      end

    # An `export` or `export_default` call at top level. `names` are the
    # exported method and constant names, `values` maps keyword names to RBS
    # types, and `default` names the constant `export_default` was given.
    # `dynamic` is true when an argument cannot be read statically.
    Export = Data.define(:kind, :names, :values, :default, :dynamic, :line)

    # A top-level method and its RBS method type.
    Def = Data.define(:name, :type, :line)

    IMPORTS = %i[import import_relative].freeze
    REQUIRES = %i[require require_relative].freeze

    attr_reader :path,
                :imports,
                :requires,
                :exports,
                :methods,
                :constants,
                :definitions,
                :errors

    def self.parse(path) = new(path, Prism.parse_file(path))

    def initialize(path, result)
      @path = path
      @imports = []
      @requires = []
      @exports = []
      # Top-level methods by name, and RBS types of top-level constants.
      @methods = {}
      @constants = {}
      # Every class and module defined, by full name: :class or :module.
      @definitions = {}
      @errors =
        result.errors.map { |error| [error.location.start_line, error.message] }
      @annotations =
        result.comments.to_h do |comment|
          [comment.location.start_line, comment.slice]
        end
      Visitor.new(self).visit(result.value)
    end

    # The rbs-inline `#: TYPE` annotation on `line`, if any.
    def annotation(line)
      text = @annotations[line]
      text[2..].strip if text&.start_with?('#:')
    end

    # The RBS type of a literal value node, or `untyped`.
    def self.literal_type(node)
      case node
      when Prism::StringNode, Prism::InterpolatedStringNode
        '::String'
      when Prism::SymbolNode
        '::Symbol'
      when Prism::IntegerNode
        '::Integer'
      when Prism::FloatNode
        '::Float'
      when Prism::TrueNode, Prism::FalseNode
        'bool'
      when Prism::NilNode
        'nil'
      when Prism::ArrayNode
        '::Array[untyped]'
      when Prism::HashNode
        '::Hash[untyped, untyped]'
      when Prism::RegularExpressionNode
        '::Regexp'
      when Prism::CallNode
        node.name == :freeze ? literal_type(node.receiver) : 'untyped'
      else
        'untyped'
      end
    end

    # An RBS method type with untyped parameters matching a `def`.
    def self.method_type(parameters)
      return '() -> untyped' unless parameters

      params = parameters.requireds.map { |node| positional(node) }
      parameters.optionals.each { |node| params << "?untyped #{node.name}" }
      if parameters.rest.is_a?(Prism::RestParameterNode)
        params << "*untyped #{parameters.rest.name}".strip
      end
      parameters.posts.each { |node| params << positional(node) }
      parameters.keywords.each do |node|
        optional = node.is_a?(Prism::OptionalKeywordParameterNode)
        params << "#{'?' if optional}#{node.name}: untyped"
      end
      block = parameters.block ? ' ?{ (?) -> untyped }' : ''
      case parameters.keyword_rest
      when Prism::KeywordRestParameterNode
        params << "**untyped #{parameters.keyword_rest.name}".strip
      when Prism::ForwardingParameterNode
        params.push('*untyped', '**untyped')
        block = ' ?{ (?) -> untyped }'
      end
      "(#{params.join(', ')})#{block} -> untyped"
    end

    def self.positional(node)
      node.respond_to?(:name) ? "untyped #{node.name}" : 'untyped'
    end
    private_class_method :positional

    # Walks the tree once, tracking the class and module nesting and whether
    # code runs at load time.
    class Visitor < Prism::Visitor
      def initialize(file)
        super()
        @file = file
        @namespace = []
        @defs = 0
        @blocks = 0
        @constant = nil
      end

      def visit_call_node(node)
        record_call(node) if node.receiver.nil?
        super
      end

      def visit_def_node(node)
        if top_level? && node.receiver.nil?
          line = node.location.start_line
          type =
            @file.annotation(line - 1) ||
              SourceFile.method_type(node.parameters)
          @file.methods[node.name.to_s] = Def.new(node.name.to_s, type, line)
        end
        nest(:@defs) { super }
      end

      def visit_block_node(node) = nest(:@blocks) { super }

      def visit_lambda_node(node) = nest(:@blocks) { super }

      def visit_class_node(node) = define(node, :class) { super }

      def visit_module_node(node) = define(node, :module) { super }

      def visit_singleton_class_node(node) = nest(:@defs) { super }

      def visit_constant_write_node(node)
        name = qualify(node.name.to_s)
        if top_level?
          @file.constants[name] = @file.annotation(node.location.start_line) ||
            SourceFile.literal_type(node.value)
        end
        assigning(name, node.value) { super }
      end

      def visit_constant_path_write_node(node)
        name = constant_name(node.target)
        assigning(name && qualify(name), node.value) { super }
      end

      private

      def record_call(node)
        if IMPORTS.include?(node.name) || REQUIRES.include?(node.name)
          record_load(node)
        elsif %i[export export_default].include?(node.name) && top_level?
          record_export(node)
        end
      end

      def record_load(node)
        args = node.arguments&.arguments || []
        return unless args.size == 1

        call =
          Call.new(
            kind: node.name.to_s,
            path: (args.first.unescaped if args.first.is_a?(Prism::StringNode)),
            file: @file.path,
            line: node.location.start_line,
            lazy: @defs.positive? || @blocks.positive?,
            constant: @constant,
          )
        list = IMPORTS.include?(node.name) ? @file.imports : @file.requires
        list << call
      end

      def record_export(node)
        args = node.arguments&.arguments || []
        names = []
        values = {}
        default = nil
        dynamic = false
        args.each do |arg|
          case arg
          when Prism::SymbolNode
            names << arg.unescaped
          when Prism::DefNode
            names << arg.name.to_s
          when Prism::KeywordHashNode
            arg.elements.each do |element|
              if element.is_a?(Prism::AssocNode) &&
                   element.key.is_a?(Prism::SymbolNode)
                values[element.key.unescaped] = SourceFile.literal_type(
                  element.value,
                )
              else
                dynamic = true
              end
            end
          else
            if node.name == :export_default
              default = constant_name(arg)
            else
              dynamic = true
            end
          end
        end
        @file.exports << Export.new(
          kind: node.name.to_s,
          names:,
          values:,
          default:,
          dynamic:,
          line: node.location.start_line,
        )
      end

      def define(node, kind, &)
        name = constant_name(node.constant_path)
        return nest(:@defs, 0, &) unless name

        name = qualify(name)
        @file.definitions[name] ||= kind
        @namespace.push(name)
        begin
          nest(:@defs, 0, &)
        ensure
          @namespace.pop
        end
      end

      # A class or module body runs at load time, so it resets `@defs`;
      # `step` 0 keeps the count while restoring it afterwards.
      def nest(counter, step = 1)
        saved = instance_variable_get(counter)
        instance_variable_set(counter, step.zero? ? 0 : saved + step)
        yield
      ensure
        instance_variable_set(counter, saved)
      end

      # Only a direct `CONST = import ...` binds the constant to the import.
      def assigning(name, value)
        saved = @constant
        import = value.is_a?(Prism::CallNode) && IMPORTS.include?(value.name)
        @constant = (name if import)
        yield
      ensure
        @constant = saved
      end

      # The constant path as written, or nil for a dynamic one like `x::Y`.
      def constant_name(node)
        case node
        when Prism::ConstantReadNode
          node.name.to_s
        when Prism::ConstantPathNode
          node.full_name
        end
      rescue Prism::ConstantPathNode::DynamicPartsInConstantPathError
        nil
      end

      def qualify(name)
        return name.delete_prefix('::') if name.start_with?('::')

        [*@namespace.last, name].join('::')
      end

      def top_level? = @namespace.empty? && @defs.zero?
    end
    private_constant :Visitor
  end
end
