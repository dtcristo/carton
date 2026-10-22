# frozen_string_literal: true

require_relative 'project'

module Carton
  module Tools
    # The names in a Project bound to imports, `CONST = import ...` or
    # `local = import ...`, and every use of each. A constant binding is seen
    # by every file loaded in the same Box (the app's files, or one Carton's);
    # a local binding only in its own file, and only when nothing reassigns it.
    class Bindings
      # A name bound to an imported Carton, with each Use of it.
      Binding =
        Data.define(:name, :local, :carton, :file, :line, :column, :uses)

      # One Reference to a binding, and the file it is in.
      Use = Data.define(:file, :reference)

      attr_reader :all

      def initialize(project)
        @project = project
        @by_key = {}
        @all = []
        @defined = Hash.new { |hash, box| hash[box] = {} }
        @project.files.each_value do |file|
          (file.definitions.keys + file.constants.keys).each do |name|
            @defined[box_of(file.path)][name] = true
          end
        end
        bind_imports
        collect_uses
      end

      # Imports matched directly against a pattern, `import('math') => { add: }`,
      # as [call, carton] pairs.
      def patterns
        @project.edges.filter_map do |edge|
          [edge.call, edge.carton] if edge.carton && edge.call.pattern
        end
      end

      # Definitions that open an imported value or a constant beneath it,
      # as [path, definition, binding] triples. A definition is a use, too.
      def reopenings
        @project.files.each_value.flat_map do |file|
          file.definition_sites.filter_map do |site|
            binding = reopened_binding(file.path, site)
            [file.path, site, binding] if binding
          end
        end
      end

      private

      def bind_imports
        clashing = {}
        @project.edges.each do |edge|
          call = edge.call
          next unless edge.carton

          key = binding_key(call)
          next unless key

          existing = @by_key[key]
          clashing[key] = true if existing && existing.carton != edge.carton
          next if existing

          @by_key[key] = Binding.new(
            name: call.constant || call.local,
            local: !call.local.nil?,
            carton: edge.carton,
            file: call.file,
            line: call.line,
            column: call.column,
            uses: [],
          )
        end
        clashing.each_key { |key| @by_key.delete(key) }
        @all = @by_key.values
      end

      def binding_key(call)
        if call.constant
          [:constant, box_of(call.file), call.constant]
        elsif call.local &&
              @project.files[call.file].local_writes[call.local] == 1
          [:local, call.file, call.local]
        end
      end

      def collect_uses
        @project.files.each_value do |file|
          file.references.each do |reference|
            binding = lookup(file.path, reference)
            binding&.uses&.push(Use.new(file: file.path, reference:))
          end
        end
      end

      # A constant resolves lexically: in `module App`, `MathTools` may be
      # `App::MathTools` or `::MathTools`.
      def lookup(path, reference)
        return @by_key[[:local, path, reference.name]] if reference.local

        constant(path, reference.name, reference.scope)
      end

      def constant(path, name, scope)
        box = box_of(path)
        candidates(name, scope).each do |candidate|
          binding = @by_key[[:constant, box, candidate]]
          return binding if binding
          return nil if @defined[box][candidate]
        end
        nil
      end

      def candidates(name, scope)
        return [name.delete_prefix('::')] if name.start_with?('::')

        parts = scope.to_s.split('::')
        [
          *parts.size.downto(1).map { |n| [*parts.first(n), name].join('::') },
          name,
        ]
      end

      def reopened_binding(path, site)
        # `module Local; class Billing` defines Local::Billing, even if an
        # outer scope imported Billing. Qualified parents resolve lexically.
        unless site.name.include?('::')
          name = [site.scope, site.name].compact.join('::')
          return @by_key[[:constant, box_of(path), name]]
        end

        parts = site.name.split('::')
        parts
          .size
          .downto(1) do |size|
            binding = constant(path, parts.first(size).join('::'), site.scope)
            return binding if binding
          end
        nil
      end

      # Files loaded in the same Box share constants: the app's, or one
      # Carton's.
      def box_of(path) = @project.owner(path)&.entrypoint
    end
  end
end
