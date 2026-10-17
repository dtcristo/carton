# frozen_string_literal: true

module Carton
  # One Import's state, attached to the plain `Ruby::Box` it runs in.
  #
  # This wraps a `Ruby::Box` rather than subclassing it: Ruby runs an autoload
  # in the Box that registered it only when that Box is exactly a `Ruby::Box`,
  # so a subclass would let a Carton's lazy autoloads run in the importer's
  # Box. Code in any Box finds the Import from `Ruby::Box.current` with
  # `Box.for`.
  class Box
    ACTIVATE_GEMS = File.expand_path('activate_gems.rb', __dir__)
    private_constant :ACTIVATE_GEMS
    ERRORS = %i[Error ImportError ExportError GemfileNotFound].freeze
    private_constant :ERRORS
    IVAR = :@carton_import
    private_constant :IVAR

    # The Import running in `ruby_box`, or nil for the Main Box and Boxes
    # Carton did not create.
    def self.for(ruby_box) = ruby_box.instance_variable_get(IVAR)

    def initialize
      @box = Ruby::Box.new
      @box.instance_variable_set(IVAR, self)
      reset_export_declaration
    end

    private

    # The whole Import lifecycle, in order: boot Carton in this Box, load the
    # target, then build its public surface with `build`. Runtime calls only
    # this, so the ordering lives here.
    def import_target(target, carton_entrypoint:, import_cache:, &build)
      configure_for_import(entrypoint: carton_entrypoint, import_cache:)
      load_import(
        target.feature,
        load_path: target.load_path,
        gems: target.gems || [],
        locked_gems: target.locked_gems,
      )
      export_public_surface(&build)
    end

    # Fresh boxes copy Master, so they start without the caller's gems. Load
    # Carton's own entrypoint so the imported file gets `import`,
    # `import_relative`, and `export`. Nested imports reuse the caller's
    # process-wide import cache.
    def configure_for_import(entrypoint:, import_cache:)
      @import_cache = import_cache
      reset_export_declaration
      add_import_load_path(File.dirname(entrypoint))
      require_in_box(entrypoint)
      share_error_classes
      snapshot_import_support
      self
    end

    # Activate the caller's gems for the target, then load it inside the box.
    def load_import(feature, load_path: nil, gems: [], locked_gems: nil)
      activate_gems(gems, locked_gems) unless gems.empty?
      add_import_load_path(load_path) if load_path

      @entrypoint = real_path(feature)
      result = require_in_box(feature)
      discover_public_entries
      result
    end

    attr_reader :import_cache, :pending_gems

    # `eval` rather than `Ruby::Box#require`, so the Box's own `Kernel#require`
    # runs, including patches such as Zeitwerk's.
    def require_in_box(feature)
      @box.eval("require #{feature.inspect}")
    end

    # Box methods run in the Box that defined them, so this Box's own copy of
    # Carton activates gems in this Box's RubyGems. `$LOAD_PATH` resolves to
    # the Box of the file being loaded, which during a nested Import is the
    # importing Carton, so activation runs from a file required here.
    def activate_gems(gems, locked_gems)
      @pending_gems = [gems, locked_gems]
      require_in_box(ACTIVATE_GEMS)
    ensure
      @pending_gems = nil
    end

    # This Box just loaded its own copy of Carton, whose error classes are new
    # objects that `rescue Carton::Error` in another Box would never match.
    # Point them at the importer's classes, so one rescue catches errors
    # raised in any Carton.
    def share_error_classes
      carton = @box.const_get(:Carton, false)
      ERRORS.each do |name|
        carton.__send__(:remove_const, name)
        carton.const_set(name, Carton.const_get(name, false))
      end
    end

    def add_import_load_path(path)
      load_path = @box.load_path
      load_path.unshift(path) unless load_path.include?(path)
    end

    # Only the imported Entrypoint declares this Carton's exports. Other files
    # it requires may call `export` for their own imports; here it is inert.
    def entrypoint?(file)
      !@entrypoint.nil? && real_path(file) == @entrypoint
    end

    def real_path(path)
      return unless path && File.absolute_path?(path) && File.file?(path)

      File.realpath(path)
    end

    def declare_export(methods, values)
      @export_declaration = @export_declaration.add(methods, values)
    end

    def declare_default(value)
      @export_declaration = @export_declaration.default(value)
    end

    # A Bare Carton's surface is the constants and top-level helpers its
    # Entrypoint defined, so importers never receive the Box itself.
    def export_public_surface(&)
      @export_declaration.public_surface(bare: method(:bare_surface), &)
    end

    def bare_surface
      constants =
        @public_constant_names.to_h do |name|
          [name, @box.const_get(name, false)]
        end
      [@public_method_entries, constants]
    end

    def reset_export_declaration
      @export_declaration = ExportDeclaration.absent
    end

    def snapshot_import_support
      @import_constant_names = @box.constants(false).map(&:to_s)
      @import_method_names = top_level_methods.keys
    end

    def discover_public_entries
      @public_constant_names =
        @box.constants(false).map(&:to_s) - @import_constant_names
      @public_method_entries = top_level_methods.except(*@import_method_names)
    end

    def top_level_methods
      @box.eval(
        'Object.private_instance_methods(false).to_h { |name| [name.to_s, method(name)] }',
      )
    end
  end
end
