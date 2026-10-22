# frozen_string_literal: true

require 'prism'

module Carton
  module Tools
    # What one Ruby file imports, requires, exports, and defines at top level,
    # read with Prism without running it. `carton rbs` and `carton check` build
    # on these facts.
    class SourceFile
      # An `import`, `import_relative`, `require`, or `require_relative` call.
      # `path` is nil when the argument is not a string literal. `lazy` is true
      # inside a method, block, or lambda, which may run after loading.
      # `constant` and `local` name the constant or local variable the call's
      # result is assigned to, and `pattern` is the Reference for a pattern
      # matched directly against it, such as `import('math') => { add: }`.
      Call =
        Data.define(
          :kind,
          :path,
          :file,
          :line,
          :lazy,
          :constant,
          :local,
          :pattern,
        ) { def relative? = kind.end_with?('_relative') }

      # A use of a name that may be bound to an import: `name` as written (a
      # constant path, or a local variable when `local`), the innermost
      # namespace it appears in, and how it is used. `kind` is :call for a
      # method call (`X.add`), :const for a constant path (`X::PI`), :fetch for
      # a lookup that raises when the name is missing (`fetch`, a `=>`
      # pattern), :lookup for one that does not (`[]`, `key?`, an `in`
      # pattern), and :value when the namespace itself is passed on, so its
      # uses cannot be followed. `member` is the name used, or nil for :value.
      # `rescued` lists the exception classes an enclosing `rescue` catches.
      Reference =
        Data.define(:name, :local, :scope, :kind, :member, :line, :rescued)

      # A class or module definition, with its name as written and the
      # enclosing namespace, before entering its body.
      Definition = Data.define(:name, :scope, :kind, :line)

      # A hash pattern matched directly against an import: its Reference
      # `kind` (:fetch for `=>`, :lookup for `in`) and the keys it reads, with
      # `'**'` for a rest pattern.
      Pattern = Data.define(:kind, :keys)

      # An `export` call at top level. `value` names the constant it exports,
      # if it is one. `keys` maps a keyword or Hash literal export's keys to
      # RBS types, or is nil. `symbol` is true when it was given a Symbol,
      # which `export` refuses. `branches` lists the enclosing `if`,
      # `unless`, and `case` branches as [conditional, branch] pairs, so two
      # calls in different branches of the same conditional are known never
      # to both run.
      Export =
        Data.define(:value, :keys, :symbol, :line, :branches) do
          def exclusive?(other)
            branches.any? do |id, branch|
              other.branches.any? do |other_id, other_branch|
                id == other_id && branch != other_branch
              end
            end
          end
        end

      IMPORTS = %i[import import_relative].freeze
      REQUIRES = %i[require require_relative].freeze

      attr_reader :path,
                  :imports,
                  :requires,
                  :exports,
                  :export_lines,
                  :constants,
                  :definitions,
                  :references,
                  :definition_sites,
                  :private_constants,
                  :local_writes,
                  :errors

      def self.parse(path) = new(path, Prism.parse_file(path))

      def initialize(path, result)
        @path = path
        @imports = []
        @requires = []
        @exports = []
        # Every possible export call, including ones whose execution or type
        # cannot be inferred, so missing-export checks stay conservative.
        @export_lines = []
        # RBS types of top-level constants.
        @constants = {}
        # Every class and module defined, by full name: :class or :module.
        @definitions = {}
        @references = []
        @definition_sites = []
        # Full names made private with `private_constant`.
        @private_constants = []
        # How many times each local variable is assigned, so a local bound to
        # an import is only followed when nothing reassigns it.
        @local_writes = Hash.new(0)
        @errors =
          result.errors.map do |error|
            [error.location.start_line, error.message]
          end
        @annotations =
          result.comments.to_h do |comment|
            [comment.location.start_line, comment.slice]
          end
        Visitor.new(self).visit(result.value)
      end

      # Whether a `# carton:dynamic` comment on `line`, or the line above,
      # marks an import as intentionally dynamic.
      def dynamic_marker?(line)
        [line, line - 1].any? do |l|
          @annotations[l]&.include?('carton:dynamic')
        end
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

      # Walks the tree once, tracking the class and module nesting and whether
      # code runs at load time.
      class Visitor < Prism::Visitor
        # Lookups by name, and whether a missing name raises.
        LOOKUPS = {
          :[] => :lookup,
          :key? => :lookup,
          :has_key? => :lookup,
          :values_at => :lookup,
          :fetch => :fetch,
          :fetch_values => :fetch,
        }.freeze
        # Calls that reach names the code does not spell out.
        ESCAPES = %i[
          keys
          to_h
          deconstruct_keys
          send
          public_send
          __send__
          method
          public_method
          const_get
          constants
          respond_to?
        ].freeze

        def initialize(file)
          super()
          @file = file
          @namespace = []
          @defs = 0
          @blocks = 0
          @constant = nil
          @local = nil
          @pattern = nil
          # Nodes already recorded as a receiver or pattern value, and the
          # constant paths that name a class or module being defined.
          @handled = {}.compare_by_identity
          @defining = {}.compare_by_identity
          @rescued = []
          @branches = []
        end

        # Code in a `begin` body may raise into its `rescue` clauses, which
        # record the classes they catch; a bare `rescue` catches StandardError.
        def visit_begin_node(node)
          return super unless node.rescue_clause

          rescuing(rescued_classes(node.rescue_clause)) do
            visit(node.statements) if node.statements
          end
          visit(node.rescue_clause)
          visit(node.else_clause) if node.else_clause
          visit(node.ensure_clause) if node.ensure_clause
        end

        def visit_rescue_modifier_node(node)
          rescuing(['StandardError']) { visit(node.expression) }
          visit(node.rescue_expression)
        end

        def visit_call_node(node)
          if node.name == :export &&
               (node.receiver.nil? || node.receiver.is_a?(Prism::SelfNode))
            @file.export_lines << node.location.start_line
          end
          record_call(node) if node.receiver.nil?
          record_use(node) if bindable?(node.receiver)
          super
        end

        def visit_constant_path_node(node)
          unless @defining[node]
            if bindable?(node.parent)
              @handled[node.parent] = true
              reference(node.parent, :const, node.name.to_s)
            end
            reference(node, :value, nil) unless @handled[node]
          end
          super
        end

        def visit_constant_read_node(node)
          reference(node, :value, nil) unless @defining[node] || @handled[node]
          super
        end

        def visit_local_variable_read_node(node)
          reference(node, :value, nil) unless @handled[node]
          super
        end

        def visit_local_variable_write_node(node)
          name = node.name.to_s
          @file.local_writes[name] += 1
          binding(:@local, name, node.value) { super }
        end

        %i[
          local_variable_operator_write_node
          local_variable_or_write_node
          local_variable_and_write_node
          local_variable_target_node
        ].each do |type|
          define_method(:"visit_#{type}") do |node|
            @file.local_writes[node.name.to_s] += 1
            super(node)
          end
        end

        def visit_match_required_node(node)
          match(node.value, node.pattern, :fetch) { super }
        end

        def visit_match_predicate_node(node)
          match(node.value, node.pattern, :lookup) { super }
        end

        def visit_def_node(node) = nest(:@defs) { super }

        def visit_block_node(node) = nest(:@blocks) { super }

        def visit_lambda_node(node) = nest(:@blocks) { super }

        def visit_class_node(node) = define(node, :class) { super }

        def visit_module_node(node) = define(node, :module) { super }

        def visit_case_match_node(node)
          node.conditions.each do |condition|
            next unless condition.is_a?(Prism::InNode)

            match(node.predicate, condition.pattern, :lookup)
          end
          visit_branches(
            node,
            node.predicate,
            node.conditions,
            node.else_clause,
          )
        end

        def visit_case_node(node)
          visit_branches(
            node,
            node.predicate,
            node.conditions,
            node.else_clause,
          )
        end

        def visit_if_node(node)
          visit_branches(
            node,
            node.predicate,
            [node.statements],
            node.subsequent,
          )
        end

        def visit_unless_node(node)
          visit_branches(
            node,
            node.predicate,
            [node.statements],
            node.else_clause,
          )
        end

        def visit_singleton_class_node(node) = nest(:@defs) { super }

        def visit_constant_write_node(node)
          name = qualify(node.name.to_s)
          if top_level?
            @file.constants[name] = SourceFile.literal_type(node.value)
          end
          binding(:@constant, name, node.value) { super }
        end

        def visit_constant_path_write_node(node)
          name = constant_name(node.target)
          @defining[node.target] = true
          binding(:@constant, name && qualify(name), node.value) { super }
        end

        private

        def record_call(node)
          if IMPORTS.include?(node.name) || REQUIRES.include?(node.name)
            record_load(node)
          elsif node.name == :export && top_level?
            record_export(node)
          elsif node.name == :private_constant && @namespace.any?
            record_private(@namespace.last, node)
          end
        end

        def record_load(node)
          args = node.arguments&.arguments || []
          return unless args.size == 1

          call =
            Call.new(
              kind: node.name.to_s,
              path:
                (args.first.unescaped if args.first.is_a?(Prism::StringNode)),
              file: @file.path,
              line: node.location.start_line,
              lazy: @defs.positive? || @blocks.positive?,
              constant: @constant,
              local: @local,
              pattern: (@pattern.last if @pattern&.first.equal?(node)),
            )
          list = IMPORTS.include?(node.name) ? @file.imports : @file.requires
          list << call
        end

        def record_export(node)
          args = node.arguments&.arguments || []
          arg = args.first if args.size == 1
          @file.exports << Export.new(
            value: constant_name(arg),
            keys: hash_types(arg),
            symbol: arg.is_a?(Prism::SymbolNode) || arg.is_a?(Prism::DefNode),
            line: node.location.start_line,
            branches: @branches.dup,
          )
        end

        # `export version: '1.0'` or `export({ version: '1.0' })`: each
        # Symbol key's RBS type, or nil when a key is not a Symbol literal.
        def hash_types(node)
          case node
          when Prism::KeywordHashNode, Prism::HashNode
            node.elements.to_h do |element|
              unless element.is_a?(Prism::AssocNode) &&
                       element.key.is_a?(Prism::SymbolNode)
                return nil
              end

              [element.key.unescaped, SourceFile.literal_type(element.value)]
            end
          end
        end

        # Visit a conditional's predicate, then each branch and the else
        # branch under its own [conditional, branch] entry.
        def visit_branches(node, predicate, branches, otherwise)
          visit(predicate) if predicate
          id = node.location.start_offset
          [*branches, otherwise].each_with_index do |branch, index|
            next unless branch

            @branches.push([id, index])
            begin
              visit(branch)
            ensure
              @branches.pop
            end
          end
        end

        # A method call on a name that may be bound to an import.
        def record_use(node)
          receiver = node.receiver
          @handled[receiver] = true
          if node.name == :private_constant
            record_private(qualify(constant_name(receiver).to_s), node)
          elsif LOOKUPS.key?(node.name)
            record_lookup(receiver, node)
          elsif ESCAPES.include?(node.name)
            reference(receiver, :value, nil)
          else
            reference(receiver, :call, node.name.to_s)
          end
        end

        # `fetch` with a default or a block does not raise, and only
        # `values_at` and `fetch_values` read every argument.
        def record_lookup(receiver, node)
          args = node.arguments&.arguments || []
          args = args.first(1) unless %i[values_at fetch_values].include?(
            node.name,
          )
          keys = args.map { |arg| literal_key(arg) }
          if keys.empty? || keys.include?(nil)
            return reference(receiver, :value, nil)
          end

          kind = LOOKUPS[node.name]
          kind = :lookup if node.name == :fetch &&
            (node.block || node.arguments.arguments.size > 1)
          keys.each { |key| reference(receiver, kind, key) }
        end

        def record_private(namespace, node)
          (node.arguments&.arguments || []).each do |arg|
            next unless arg.is_a?(Prism::SymbolNode)

            @file.private_constants << [namespace, arg.unescaped].reject(
              &:empty?
            ).join('::')
          end
        end

        def match(value, pattern, kind)
          keys = pattern_keys(pattern)
          saved = @pattern
          if keys && bindable?(value)
            @handled[value] = true
            keys.each do |key|
              if key == '**'
                reference(value, :value, nil)
              else
                reference(value, kind, key)
              end
            end
          elsif keys && import_call?(value)
            @pattern = [value, Pattern.new(kind:, keys:)]
          end
          yield if block_given?
        ensure
          @pattern = saved
        end

        # The keys a hash pattern reads, with `'**'` for a rest pattern, or
        # nil for any other pattern.
        def pattern_keys(pattern)
          return unless pattern.is_a?(Prism::HashPatternNode)

          keys =
            pattern.elements.map do |element|
              key = element.key if element.is_a?(Prism::AssocNode)
              key.is_a?(Prism::SymbolNode) ? key.unescaped : '**'
            end
          keys << '**' if pattern.rest.is_a?(Prism::AssocSplatNode)
          keys
        end

        def literal_key(node)
          unless node.is_a?(Prism::SymbolNode) || node.is_a?(Prism::StringNode)
            return
          end

          node.unescaped
        end

        def reference(node, kind, member)
          local = node.is_a?(Prism::LocalVariableReadNode)
          name = local ? node.name.to_s : constant_name(node)
          return unless name

          @file.references << Reference.new(
            name:,
            local:,
            scope: @namespace.last,
            kind:,
            member:,
            line: node.location.start_line,
            rescued: @rescued.flatten.uniq,
          )
        end

        def rescuing(classes)
          @rescued.push(classes)
          yield
        ensure
          @rescued.pop
        end

        def rescued_classes(clause)
          classes = []
          while clause
            names = clause.exceptions.filter_map { |node| constant_name(node) }
            classes.concat(names.empty? ? ['StandardError'] : names)
            clause = clause.subsequent
          end
          classes
        end

        def bindable?(node)
          node.is_a?(Prism::ConstantReadNode) ||
            node.is_a?(Prism::ConstantPathNode) ||
            node.is_a?(Prism::LocalVariableReadNode)
        end

        def import_call?(node)
          node.is_a?(Prism::CallNode) && node.receiver.nil? &&
            IMPORTS.include?(node.name)
        end

        def define(node, kind, &)
          mark_defining(node.constant_path)
          name = constant_name(node.constant_path)
          return nest(:@defs, 0, &) unless name

          @file.definition_sites << Definition.new(
            name:,
            scope: @namespace.last,
            kind:,
            line: node.location.start_line,
          )

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

        # The constant path a class or module definition names is not a use.
        def mark_defining(node)
          while node.is_a?(Prism::ConstantPathNode) ||
                  node.is_a?(Prism::ConstantReadNode)
            @defining[node] = true
            node = node.respond_to?(:parent) ? node.parent : nil
          end
        end

        # Only a direct `CONST = import ...` or `local = import ...` binds the
        # name to the import.
        def binding(ivar, name, value)
          saved = instance_variable_get(ivar)
          instance_variable_set(ivar, (name if import_call?(value)))
          yield
        ensure
          instance_variable_set(ivar, saved)
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
end
