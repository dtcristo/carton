# frozen_string_literal: true

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
    # built at runtime cannot be followed.
    def import_problems
      @project.edges.filter_map do |edge|
        call = edge.call
        if edge.error
          error(call.file, call.line, edge.error)
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

    # The same rules `Carton::ExportError` enforces at runtime.
    def declaration_problems(file)
      defaults, named =
        file.exports.partition { |e| e.kind == 'export_default' }
      problems =
        defaults
          .drop(1)
          .map do |export|
            error(
              file.path,
              export.line,
              'export_default may be called only once per file',
            )
          end
      if defaults.any? && named.any?
        problems << error(
          file.path,
          named.first.line,
          'export_default cannot be combined with export; ' \
            'put the other names inside the default value',
        )
      end
      seen = {}
      named.each do |export|
        (export.names + export.values.keys).each do |name|
          if seen.key?(name)
            problems << error(
              file.path,
              export.line,
              "export name given more than once: #{name}",
            )
          end
          seen[name] = true
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

    def display(path) = Project.relative(path)

    def error(file, line, message) = Problem.new(:error, file, line, message)

    def warning(file, line, message)
      Problem.new(:warning, file, line, message)
    end
  end
end
