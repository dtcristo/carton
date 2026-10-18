# frozen_string_literal: true

require_relative 'project'

module Carton
  # The names in a Project bound to imports, `CONST = import ...` or
  # `local = import ...`, and every use of each. A constant binding is seen
  # by every file loaded in the same Box (the app's files, or one Carton's);
  # a local binding only in its own file, and only when nothing reassigns it.
  class Bindings
    # A name bound to an imported Carton, with each Use of it.
    Binding = Data.define(:name, :unit, :file, :line, :uses)

    # One Reference to a binding, and the file it is in.
    Use = Data.define(:file, :reference)

    attr_reader :all

    def initialize(project)
      @project = project
      @by_key = {}
      @all = []
      bind_imports
      collect_uses
    end

    # Imports matched directly against a pattern, `import('math') => { add: }`,
    # as [call, unit] pairs.
    def patterns
      @project.edges.filter_map do |edge|
        [edge.call, edge.unit] if edge.unit && edge.call.pattern
      end
    end

    private

    def bind_imports
      clashing = {}
      @project.edges.each do |edge|
        call = edge.call
        next unless edge.unit

        key = binding_key(call)
        next unless key

        existing = @by_key[key]
        clashing[key] = true if existing && existing.unit != edge.unit
        next if existing

        @by_key[key] = Binding.new(
          name: call.constant || call.local,
          unit: edge.unit,
          file: call.file,
          line: call.line,
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

      box = box_of(path)
      candidates(reference).each do |name|
        binding = @by_key[[:constant, box, name]]
        return binding if binding
      end
      nil
    end

    def candidates(reference)
      name = reference.name
      return [name.delete_prefix('::')] if name.start_with?('::')

      parts = reference.scope.to_s.split('::')
      [
        *parts.size.downto(1).map { |n| [*parts.first(n), name].join('::') },
        name,
      ]
    end

    # Files loaded in the same Box share constants: the app's, or one
    # Carton's.
    def box_of(path) = @project.owner(path)&.entrypoint
  end
end
