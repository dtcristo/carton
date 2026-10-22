# frozen_string_literal: true

require_relative 'bindings'
require_relative 'import_graph'
require_relative 'project'

module Carton
  module Tools
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
        @reopenings = @bindings.reopenings
      end

      def problems
        [
          *parse_errors,
          *import_problems,
          *cycles,
          *requires_into_cartons,
          *undeclared_gems,
          *export_problems,
          *missing_export_declarations,
          *missing_exports,
          *private_constant_references,
          *unused_imports,
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
        ImportGraph
          .new(@project)
          .cycles
          .map do |cycle|
            first = cycle.first.call
            names =
              [cycle.last.carton, *cycle.map(&:carton)].map do |carton|
                name(carton)
              end
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

      # A `require` of an imported Carton's file from outside it loads a second
      # copy into the requiring Box, which the runtime cannot detect.
      def requires_into_cartons
        @project.requires.filter_map do |call|
          path = @project.locate(call) or next
          carton = @project.carton_containing(path) or next
          next if carton == @project.owner(call.file)

          error(
            call.file,
            call.line,
            "#{call.kind} '#{call.path}' loads a second copy of the #{name(carton)} " \
              "Carton's #{path == carton.entrypoint ? 'Entrypoint' : 'file'}: import it instead",
          )
        end
      end

      # A Gem Carton's gemspec is its manifest: every other gem it imports or
      # requires must be a runtime dependency there. Under a bundled app it
      # still loads today, since the Carton sees the app's whole lockfile, but
      # it fails wherever the gem is installed without that dependency. Default
      # gems and Carton itself load in every Box.
      def undeclared_gems
        @project.cartons.each_value.flat_map do |carton|
          spec = @project.gem_for(carton.entrypoint) or next []
          declared = [spec.name, *spec.runtime_dependencies.map(&:name)]
          calls = carton.files.flat_map { |path| loads(path) }
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
                'export outside an Entrypoint does nothing: ' \
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
        file.exports.each_with_index.flat_map do |export, index|
          problems = []
          if export.symbol
            problems << error(
              file.path,
              export.line,
              'export takes the value to export, not a name: ' \
                'export a module, or keywords for a Hash',
            )
          end
          if file.exports.first(index).any? { |e| !e.exclusive?(export) }
            problems << error(
              file.path,
              export.line,
              'export may be called only once per Entrypoint',
            )
          end
          problems
        end
      end

      # Only imported Entrypoints must export. The presence of a call is
      # checked without proving that every path through the file reaches it.
      def missing_export_declarations
        @project.cartons.each_value.filter_map do |carton|
          unless @project.files.fetch(carton.entrypoint).export_lines.empty?
            next
          end

          error(carton.entrypoint, 1, 'an imported Entrypoint must call export')
        end
      end

      # A `fetch` of a key a Carton's exported Hash does not have, which
      # raises KeyError. `[]`, `key?`, and `in` patterns return nil or false
      # instead. Only keyword and Hash literal exports are checked, since
      # other exports' members are not declared in one place.
      def missing_exports
        from_bindings =
          @bindings.all.flat_map do |binding|
            names = hash_keys(binding.carton) or next []
            binding.uses.filter_map do |use|
              reference = use.reference
              next unless raises?(reference)
              next if names.include?(reference.member)

              error(
                use.file,
                reference.line,
                missing_message(
                  "#{reference.name}.fetch(:#{reference.member})",
                  reference.member,
                  binding.carton,
                  names,
                ),
              )
            end
          end
        from_bindings + missing_pattern_keys
      end

      def missing_pattern_keys
        @bindings.patterns.flat_map do |call, carton|
          names = hash_keys(carton)
          next [] unless names && call.pattern.kind == :fetch

          (call.pattern.keys - ['**'] - names).map do |key|
            error(
              call.file,
              call.line,
              missing_message(
                "#{call.kind}('#{call.path}') => { #{key}: }",
                key,
                carton,
                names,
              ),
            )
          end
        end
      end

      # A `fetch` or `=>` pattern raises unless an enclosing `rescue` catches
      # what it raises.
      def raises?(reference)
        return false unless reference.kind == :fetch

        raised = %w[
          KeyError
          IndexError
          NoMatchingPatternKeyError
          NoMatchingPatternError
        ]
        !rescued?(reference, raised)
      end

      def rescued?(reference, raised)
        caught = reference.rescued.map { |name| name.delete_prefix('::') }
        caught.intersect?([*raised, 'StandardError', 'Exception'])
      end

      def missing_message(code, key, carton, names)
        "#{code}: the #{name(carton)} Carton's export has no key #{key} " \
          "(it has #{names.join(', ')})"
      end

      # The keys of the Hash a Carton exports, or nil when it exports
      # something else or its keys cannot be read statically.
      def hash_keys(carton)
        exports = @project.files.fetch(carton.entrypoint).exports
        exports.first.keys&.keys if exports.size == 1
      end

      # `Billing::Tax`, where the billing Carton exports `Billing` and
      # `Billing` makes `Tax` private, raises NameError.
      def private_constant_references
        @bindings.all.flat_map do |binding|
          constant = exported_constant(binding.carton) or next []
          privates =
            binding.carton.files.flat_map do |path|
              @project.files.fetch(path).private_constants
            end
          binding.uses.filter_map do |use|
            reference = use.reference
            next unless reference.kind == :const
            next unless privates.include?("#{constant}::#{reference.member}")
            next if rescued?(reference, %w[NameError])

            error(
              use.file,
              reference.line,
              "#{reference.name}::#{reference.member} is a private constant " \
                "of the #{name(binding.carton)} Carton",
            )
          end
        end
      end

      # The constant a Carton exports, or nil.
      def exported_constant(carton)
        exports = @project.files.fetch(carton.entrypoint).exports
        exports.first.value if exports.size == 1
      end

      # A binding with no reads may be dead code. Constants on a Carton's
      # Public Surface are also used implicitly by its Importers.
      def unused_imports
        @bindings.all.filter_map do |binding|
          next unless binding.uses.empty?
          next if public_binding?(binding)
          next if @reopenings.any? { |_, _, used| used.equal?(binding) }

          warning(
            binding.file,
            binding.line,
            "#{binding.name} is bound to an import of the #{name(binding.carton)} " \
              'Carton but never used',
          )
        end
      end

      def public_binding?(binding)
        return false if binding.local

        carton = @project.owner(binding.file) or return false
        exports = @project.files.fetch(carton.entrypoint).exports

        exports.any? do |export|
          name = export.value&.delete_prefix('::')
          name &&
            (binding.name == name || binding.name.start_with?("#{name}::"))
        end
      end

      # Classes and modules returned by Imports are shared objects. Opening
      # one, or defining a constant beneath it, mutates that shared object.
      def reopened_classes
        @reopenings.filter_map do |path, site, binding|
          next if binding.carton == @project.owner(path)

          warning(
            path,
            site.line,
            "#{site.kind} #{site.name} opens #{binding.name} from the " \
              "#{name(binding.carton)} Carton, changing a shared class or module: " \
              'subclass it or use a refinement instead',
          )
        end
      end

      def display(path) = @project.relative(path)

      def name(carton) = @project.label(carton)

      def error(file, line, message) = Problem.new(:error, file, line, message)

      def warning(file, line, message)
        Problem.new(:warning, file, line, message)
      end
    end
  end
end
