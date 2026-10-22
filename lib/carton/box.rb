# frozen_string_literal: true

module Carton
  # A Carton Box: one Import's state, attached to the plain `Ruby::Box` it
  # runs in. It wraps a `Ruby::Box` rather than subclassing it, because Ruby
  # keeps autoloads in the Box that registered them only for a plain
  # `Ruby::Box`. Code in any Box finds the Import from `Ruby::Box.current`
  # with `Box.for`.
  class Box
    ACTIVATE_GEMS = File.expand_path('activate_gems.rb', __dir__)
    private_constant :ACTIVATE_GEMS
    LOADED_FEATURES = File.expand_path('loaded_features.rb', __dir__)
    private_constant :LOADED_FEATURES
    ERRORS = %i[Error ImportError ExportError GemfileNotFound].freeze
    private_constant :ERRORS
    IVAR = :@carton_import
    private_constant :IVAR

    NO_EXPORT = Object.new.freeze
    private_constant :NO_EXPORT

    # The Import running in `ruby_box`, or nil for the Main Box and Boxes
    # Carton did not create.
    def self.for(ruby_box) = ruby_box.instance_variable_get(IVAR)

    def initialize
      @box = Ruby::Box.new
      @box.instance_variable_set(IVAR, self)
      route_autoloads_through_kernel_require
      reset_export
    end

    private

    # The whole Import lifecycle, in order: boot Carton in this Box, load the
    # target, then return its Export. Runtime calls only this, so the ordering
    # lives here.
    def import_target(target, library:, import_cache:)
      configure_for_import(library:, import_cache:)
      load_import(
        target.feature,
        load_path: target.load_path,
        gems: target.gems || [],
        locked_gems: target.locked_gems,
      )
      record_used_gems(target)
      exported_value
    end

    # The gems this Carton depends on: its Gem Closure, plus the locked gems
    # whose files it has loaded, such as an Undeclared Gem the Importer's
    # lockfile allows. A later Importer must agree on these versions to share
    # the Carton, so they are read again at each check, after any lazy
    # requires.
    def record_used_gems(target)
      target.gem_usage = -> { used_gems(target) }
    end

    def used_gems(target)
      gems = target.gems || []
      locked = (target.locked_gems || []) - gems
      return gems if locked.empty?

      gems + GemActivation.owning(locked, loaded_features)
    end

    # `Ruby::Box#eval` does not switch the loading Box, so during a nested
    # Import `$LOADED_FEATURES` there would be the Importer's. A file loaded
    # in this Box reads this Box's.
    def loaded_features
      @box.eval("load #{LOADED_FEATURES.inspect}")
      features = @loaded_features
      @loaded_features = nil
      features
    end

    def receive_loaded_features(features)
      @loaded_features = features
    end

    # New Boxes copy Master, so they start without the Importer's gems. Load
    # Carton's own library so the imported file gets `import`,
    # `import_relative`, and `export`. Nested imports reuse the Importer's
    # process-wide import cache.
    def configure_for_import(library:, import_cache:)
      @import_cache = import_cache
      reset_export
      add_import_load_path(File.dirname(library))
      require_in_box(library)
      share_error_classes
      self
    end

    # Activate the Importer's gems for the target, then load it in this Box.
    def load_import(feature, load_path: nil, gems: [], locked_gems: nil)
      activate_gems(gems, locked_gems) unless gems.empty?
      add_import_load_path(load_path) if load_path
      @entrypoint = real_path(feature)
      require_in_box(feature)
    end

    attr_reader :import_cache, :pending_gems

    # Ruby 4.0.7 loads an autoload registered in this Box with
    # `Ruby::Box#require`, which skips the Box's `Kernel#require` and so any
    # patch on it, such as Zeitwerk's (Bug #21830, fixed on Ruby master). Send
    # it through `Kernel#require` in this Box instead.
    def route_autoloads_through_kernel_require
      box = @box
      box.define_singleton_method(:require) do |path|
        box.eval("require #{path.to_s.inspect}")
      end
    end

    # `eval` rather than `Ruby::Box#require`, so the Box's own `Kernel#require`
    # runs, including patches such as Zeitwerk's.
    def require_in_box(feature)
      @box.eval("require #{feature.inspect}")
    end

    # Box methods run in the Box that defined them, so this Box's own copy of
    # Carton activates gems in this Box's RubyGems. `$LOAD_PATH` resolves to
    # the Box of the file being loaded, which during a nested Import is the
    # Importer, so activation runs from a file required here.
    def activate_gems(gems, locked_gems)
      @pending_gems = [gems, locked_gems]
      require_in_box(ACTIVATE_GEMS)
    ensure
      @pending_gems = nil
    end

    # This Box just loaded its own copy of Carton, whose error classes are new
    # objects that `rescue Carton::Error` in another Box would never match.
    # Point them at the Importer's classes, so one rescue catches errors
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

    # Only the imported Entrypoint declares this Carton's Export. Other files
    # it requires may call `export` for their own imports; here it is inert.
    def entrypoint?(file)
      !@entrypoint.nil? && real_path(file) == @entrypoint
    end

    def real_path(path)
      return unless path && File.absolute_path?(path) && File.file?(path)

      File.realpath(path)
    end

    def declare_export(value)
      unless NO_EXPORT.equal?(@export)
        raise ExportError, 'export may be called only once per Entrypoint'
      end

      @export = value
    end

    # Every Entrypoint deliberately chooses the value its Importers receive.
    def exported_value
      if NO_EXPORT.equal?(@export)
        raise ExportError,
              "#{@entrypoint} must call export: export a module or another value"
      end

      @export
    end

    def reset_export
      @export = NO_EXPORT
    end
  end
end
