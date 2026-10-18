# frozen_string_literal: true

require_relative 'bindings'
require_relative 'export_methods'
require_relative 'exports'
require_relative 'project'

module Carton
  # Problems `carton check` finds in a Project without running it. An error
  # is certain to fail or misbehave when the code runs. A warning is
  # something a dynamic program could still get right.
  class Checks
    Problem =
      Data.define(:level, :file, :line, :message) do
        def error? = level == :error
      end

    def initialize(project)
      @project = project
      @bindings = Bindings.new(project)
    end

    def problems
      [
        *parse_errors,
        *import_problems,
        *cycles,
        *requires_into_cartons,
        *undeclared_gems,
        *export_problems,
        *bare_collisions,
        *missing_exports,
        *private_constant_references,
        *unused_imports,
        *unused_exports,
        *reopened_classes,
      ].sort_by { |problem| [problem.file, problem.line, problem.message] }
    end

    private

    def parse_errors
      @project.files.each_value.flat_map do |file|
        file.errors.map { |line, message| error(file.path, line, message) }
      end
    end

    # Missing paths and files inside a Carton raise at runtime. A name not on
    # the load path may come from a gem activated at runtime, and a path
    # built at runtime cannot be followed. `# carton:dynamic` on an import
    # says either is intended, such as plugin discovery.
    def import_problems
      @project.edges.filter_map do |edge|
        call = edge.call
        if edge.error
          error(call.file, call.line, edge.error)
        elsif @project.files.fetch(call.file).dynamic_marker?(call.line)
          next
        elsif edge.unfound
          warning(
            call.file,
            call.line,
            "cannot find #{call.path} on the load path: pass -I DIR, " \
              'or run under bundle exec',
          )
        elsif call.path.nil?
          warning(
            call.file,
            call.line,
            "#{call.kind} path is not a literal, so it is not checked",
          )
        end
      end
    end

    # An import cycle raises `Carton::ImportError` when every import in it
    # runs while its file loads. An import inside a method or block may run
    # after the other Carton has loaded.
    def cycles
      graph = Hash.new { |hash, key| hash[key] = [] }
      @project.edges.each do |edge|
        from = @project.owner(edge.call.file)
        graph[from.entrypoint] << edge if from && edge.unit
      end
      find_cycles(graph).map do |cycle|
        first = cycle.first.call
        names = [cycle.last.unit, *cycle.map(&:unit)].map(&:name)
        message = "import cycle: #{names.join(' -> ')}"
        if cycle.any? { |edge| edge.call.lazy }
          warning(
            first.file,
            first.line,
            "#{message} (an import runs lazily, so it may load)",
          )
        else
          error(first.file, first.line, message)
        end
      end
    end

    # Each elementary cycle once, starting from its smallest Entrypoint. Of
    # parallel imports between the same Cartons, the eager one counts.
    def find_cycles(graph)
      cycles = []
      graph.each_key.to_a.each { |start| walk(graph, start, start, [], cycles) }
      cycles
        .sort_by { |cycle| cycle.count { |edge| edge.call.lazy } }
        .uniq { |cycle| cycle.map { |edge| edge.unit.entrypoint } }
    end

    def walk(graph, start, node, path, cycles)
      graph[node].each do |edge|
        target = edge.unit.entrypoint
        if target == start
          cycles << [*path, edge]
        elsif target > start && path.none? { |e| e.unit.entrypoint == target }
          walk(graph, start, target, [*path, edge], cycles)
        end
      end
    end

    # A `require` of an imported Carton's file from outside it loads a second
    # copy into the requiring Box, which the runtime cannot detect.
    def requires_into_cartons
      @project.requires.filter_map do |call|
        path = @project.locate(call) or next
        unit = @project.unit_containing(path) or next
        next if unit == @project.owner(call.file)

        error(
          call.file,
          call.line,
          "#{call.kind} '#{call.path}' loads a second copy of the #{unit.name} " \
            "Carton's #{path == unit.entrypoint ? 'Entrypoint' : 'file'}: import it instead",
        )
      end
    end

    # A gem Carton's gemspec is its manifest: every other gem it imports or
    # requires must be a runtime dependency there. Under a bundled app it
    # still loads today, since the Carton sees the app's whole lockfile, but
    # it fails wherever the gem is installed without that dependency. Default
    # gems and Carton itself load in every Box.
    def undeclared_gems
      @project.units.each_value.flat_map do |unit|
        spec = @project.gem_for(unit.entrypoint) or next []
        declared = [spec.name, *spec.runtime_dependencies.map(&:name)]
        calls = unit.files.flat_map { |path| loads(path) }
        calls.filter_map do |call|
          path = @project.target(call) or next
          used = @project.gem_for(path) or next
          next if used.default_gem? || used.name == 'carton'
          next if declared.include?(used.name)

          error(
            call.file,
            call.line,
            "#{call.kind} '#{call.path}' loads the #{used.name} gem, which " \
              "#{spec.name}'s gemspec does not declare: add " \
              "spec.add_dependency '#{used.name}'",
          )
        end
      end
    end

    def loads(path)
      file = @project.files.fetch(path)
      file.imports + file.requires
    end

    def export_problems
      @project.files.each_value.flat_map do |file|
        next [] if file.exports.empty?

        if Resolver.entrypoint_for(file.path) == file.path
          declaration_problems(file)
        else
          file.exports.map do |export|
            warning(
              file.path,
              export.line,
              "#{export.kind} outside an Entrypoint does nothing: " \
                "this file is inside the Carton #{display(Resolver.entrypoint_for(file.path))}",
            )
          end
        end
      end
    end

    # The same rules `Carton::ExportError` enforces at runtime, for calls
    # that can both run: calls in different branches of one `if` or `case`
    # never do.
    def declaration_problems(file)
      defaults, named =
        file.exports.partition { |e| e.kind == 'export_default' }
      problems =
        defaults.each_with_index.filter_map do |export, index|
          next unless defaults.first(index).any? { |e| !e.exclusive?(export) }

          error(
            file.path,
            export.line,
            'export_default may be called only once per file',
          )
        end
      combined = named.find { |n| defaults.any? { |d| !d.exclusive?(n) } }
      if combined
        problems << error(
          file.path,
          combined.line,
          'export_default cannot be combined with export; ' \
            'put the other names inside the default value',
        )
      end
      named.each_with_index do |export, index|
        earlier = named.first(index).reject { |e| e.exclusive?(export) }
        seen = earlier.flat_map { |e| e.names + e.values.keys }
        (export.names + export.values.keys).each do |name|
          if seen.include?(name)
            problems << error(
              file.path,
              export.line,
              "export name given more than once: #{name}",
            )
          end
          seen << name
          if Exports.reserved?(name)
            problems << error(file.path, export.line, collision(name))
          end
        end
      end
      problems
    end

    # A Bare Carton exports its top-level methods, so the same names collide.
    def bare_collisions
      @project.units.each_value.flat_map do |unit|
        next [] unless @project.files.fetch(unit.entrypoint).exports.empty?

        unit.files.flat_map do |path|
          @project
            .files
            .fetch(path)
            .methods
            .each_value
            .filter_map do |method|
              next unless Exports.reserved?(method.name)

              error(path, method.line, collision(method.name))
            end
        end
      end
    end

    def collision(name)
      "export name #{name} would hide Carton::Exports##{name}: " \
        'rename it, or export it inside a Default Export'
    end

    # A use of a Named Export that raises because the Carton does not export
    # that name: a method call, a constant path, `fetch`, or a `=>` pattern.
    # Lookups that return nil instead, such as `[]` or an `in` pattern, are
    # not errors. Default Exports and Bare Cartons are not checked, since
    # their names are not declared in one place.
    def missing_exports
      from_bindings =
        @bindings.all.flat_map do |binding|
          names = named_exports(binding.unit) or next []
          binding.uses.filter_map do |use|
            reference = use.reference
            next unless raises?(reference)
            next if names.include?(reference.member)

            error(
              use.file,
              reference.line,
              missing_message(
                written(reference.name, reference),
                reference.member,
                binding.unit,
                names,
              ),
            )
          end
        end
      from_bindings + missing_pattern_keys
    end

    def missing_pattern_keys
      @bindings.patterns.flat_map do |call, unit|
        names = named_exports(unit)
        next [] unless names && call.pattern.kind == :fetch

        (call.pattern.keys - ['**'] - names).map do |key|
          error(
            call.file,
            call.line,
            missing_message(
              "#{call.kind}('#{call.path}') => { #{key}: }",
              key,
              unit,
              names,
            ),
          )
        end
      end
    end

    # A use raises unless an enclosing `rescue` catches what it raises, as
    # the examples do to show that private constants stay private.
    def raises?(reference)
      raised =
        case reference.kind
        when :const
          %w[NameError]
        when :call
          return false if Exports.reserved?(reference.member)

          %w[NoMethodError NameError]
        when :fetch
          %w[
            KeyError
            IndexError
            NoMatchingPatternKeyError
            NoMatchingPatternError
          ]
        else
          return false
        end
      !rescued?(reference, raised)
    end

    def rescued?(reference, raised)
      caught = reference.rescued.map { |name| name.delete_prefix('::') }
      caught.intersect?([*raised, 'StandardError', 'Exception'])
    end

    def written(name, reference)
      case reference.kind
      when :const
        "#{name}::#{reference.member}"
      when :call
        "#{name}.#{reference.member}"
      else
        "#{name}.fetch(:#{reference.member})"
      end
    end

    def missing_message(code, name, unit, names)
      "#{code}: the #{unit.name} Carton has no export #{name} " \
        "(it exports #{names.join(', ')})"
    end

    # The names a Carton exports with `export`, or nil when they cannot be
    # known statically.
    def named_exports(unit)
      exports = @project.files.fetch(unit.entrypoint).exports
      if exports.empty? ||
           exports.any? { |e| e.kind == 'export_default' || e.dynamic }
        return
      end

      exports.flat_map { |export| export.names + export.values.keys }
    end

    # `Billing::Tax`, where the billing Carton's Default Export `Billing`
    # makes `Tax` private, raises NameError.
    def private_constant_references
      @bindings.all.flat_map do |binding|
        default = default_export(binding.unit) or next []
        privates =
          binding.unit.files.flat_map do |path|
            @project.files.fetch(path).private_constants
          end
        binding.uses.filter_map do |use|
          reference = use.reference
          next unless reference.kind == :const
          next unless privates.include?("#{default}::#{reference.member}")
          next if rescued?(reference, %w[NameError])

          error(
            use.file,
            reference.line,
            "#{reference.name}::#{reference.member} is a private constant " \
              "of the #{binding.unit.name} Carton",
          )
        end
      end
    end

    # A binding nothing reads. A top-level constant in a Bare Carton is part
    # of its surface, and one named by `export` is exported, so neither is
    # unused.
    def unused_imports
      @bindings.all.filter_map do |binding|
        next unless binding.uses.empty?
        next if exported_binding?(binding)

        warning(
          binding.file,
          binding.line,
          "#{binding.name} is bound to an import of the #{binding.unit.name} " \
            'Carton but never used',
        )
      end
    end

    def exported_binding?(binding)
      unit = @project.owner(binding.file) or return false
      exports = @project.files.fetch(unit.entrypoint).exports
      return !binding.name.include?('::') if exports.empty?

      exports.any? { |export| export.names.include?(binding.name) }
    end

    # A Named Export no importer uses. Skipped when any import of the
    # Carton is not followed, or passes the namespace on, since its uses
    # cannot all be seen.
    def unused_exports
      @project.units.each_value.flat_map do |unit|
        next [] unless named_exports(unit)

        used = used_names(unit) or next []

        @project
          .files
          .fetch(unit.entrypoint)
          .exports
          .flat_map do |export|
            (export.names + export.values.keys)
              .reject { |n| used.include?(n) }
              .map do |name|
                warning(
                  unit.entrypoint,
                  export.line,
                  "export #{name} of the #{unit.name} Carton is never used by " \
                    'an importer',
                )
              end
          end
      end
    end

    # Every Named Export name the Carton's importers use, or nil when an
    # import is not followed or passes the namespace on.
    def used_names(unit)
      per_import =
        @project
          .edges
          .select { |edge| edge.unit == unit }
          .map { |edge| names_used_by(edge.call) }
      per_import.flatten unless per_import.include?(nil)
    end

    def names_used_by(call)
      if call.pattern
        call.pattern.keys unless call.pattern.keys.include?('**')
      elsif (binding = @bindings.for(call))
        uses = binding.uses.map(&:reference)
        uses.map(&:member) unless uses.any? { |use| use.kind == :value }
      end
    end

    # `class Billing::Invoice`, or `class Billing`, in a Box that imported
    # Billing reopens a class another Carton defined. Classes are shared, so
    # the change reaches every Carton that uses it.
    def reopened_classes
      @project.files.each_value.flat_map do |file|
        file.definition_sites.filter_map do |site|
          root = site.name.delete_prefix('::').split('::').first
          binding = @bindings.constant(file.path, root, site.scope) or next
          next if binding.unit == @project.owner(file.path)

          warning(
            file.path,
            site.line,
            "#{site.kind} #{site.name} reopens #{root} from the " \
              "#{binding.unit.name} Carton, which changes it for every " \
              'Carton that shares it: subclass it or use a refinement instead',
          )
        end
      end
    end

    def default_export(unit)
      @project
        .files
        .fetch(unit.entrypoint)
        .exports
        .find { |e| e.kind == 'export_default' }
        &.default
    end

    def display(path) = Project.relative(path)

    def error(file, line, message) = Problem.new(:error, file, line, message)

    def warning(file, line, message)
      Problem.new(:warning, file, line, message)
    end
  end
end
