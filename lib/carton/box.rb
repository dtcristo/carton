# frozen_string_literal: true

module Carton
  # A Carton Box: one Import's state, attached to the plain `Ruby::Box` it
  # runs in. It wraps a `Ruby::Box` rather than subclassing it, because Ruby
  # keeps autoloads in the Box that registered them only for a plain
  # `Ruby::Box`. Code in any Box finds the Import from `Ruby::Box.current`
  # with `Box.for`.
  #
  # Every Box object is created by the Main Box's loader, so its methods run
  # in the Main Box and its state is shared by every Box that reaches it.
  class Box
    # Carton's own library, which every Carton Box loads so its Entrypoint can
    # call `import` and `export`. It is not an Entrypoint.
    LIBRARY = File.expand_path('../carton.rb', __dir__)
    private_constant :LIBRARY
    ACTIVATE_GEMS = File.expand_path('activate_gems.rb', __dir__)
    private_constant :ACTIVATE_GEMS
    LOADED_FEATURES = File.expand_path('loaded_features.rb', __dir__)
    private_constant :LOADED_FEATURES
    IVAR = :@carton_import
    private_constant :IVAR

    NO_EXPORT = Object.new.freeze
    private_constant :NO_EXPORT

    # The Import running in `ruby_box`, or nil for the Main Box and Boxes
    # Carton did not create.
    def self.for(ruby_box) = ruby_box.instance_variable_get(IVAR)

    # The process-wide cache that nested imports in this Box share.
    attr_reader :import_cache

    # The Export the Entrypoint declared.
    attr_reader :export

    def initialize(import_cache)
      @box = Ruby::Box.new
      @box.instance_variable_set(IVAR, self)
      @import_cache = import_cache
      @export = NO_EXPORT
      @lock = Thread::Mutex.new
      route_autoloads_through_kernel_require
    end

    # The whole Import, in order: boot Carton in this Box, activate the
    # Importer's gems, load the Entrypoint, then require its Export. A Box
    # serves one Import; once it finishes, `export` is inert here.
    #
    # New Boxes copy Master, so they start without the Importer's gems or
    # Carton. `gems` is the Gem Closure to activate, and `locked_gems` the
    # Importer's locked specs when it ran Bundler setup.
    def import(target, gems:, locked_gems:)
      @gems = gems
      @locked_gems = locked_gems
      add_load_path(File.dirname(LIBRARY))
      require_in_box(LIBRARY)
      share_error_classes
      require_in_box(ACTIVATE_GEMS) unless gems.empty?
      add_load_path(target.load_path) if target.load_path
      @entrypoint = File.realpath(target.feature)
      require_in_box(target.feature)
      if NO_EXPORT.equal?(@export)
        raise ExportError,
              "#{@entrypoint} must call export: export a module or another value"
      end

      @imported = true
      self
    end

    # The gems activate_gems.rb activates in this Box.
    def pending_gems = [@gems, @locked_gems]

    # The gems this Carton depends on: its Gem Closure, plus the locked gems
    # whose files it has loaded, such as an Undeclared Gem the Importer's
    # lockfile allows. A later Importer must agree on these versions to share
    # the Carton, so they are read again at each check, after any lazy
    # requires.
    def used_gems
      locked = (@locked_gems || []) - @gems
      return @gems if locked.empty?

      @gems + GemActivation.owning(locked, loaded_features)
    end

    # Called by loaded_features.rb in this Box.
    def receive_loaded_features(features)
      @loaded_features = features
    end

    # Only the imported Entrypoint declares this Carton's Export. Other files
    # it requires may call `export` for their own imports; here it is inert,
    # as it is in the Entrypoint once the Import finishes.
    def entrypoint?(file)
      return false if @imported || !@entrypoint || !file || !File.file?(file)

      File.realpath(file) == @entrypoint
    end

    def declare_export(value)
      unless NO_EXPORT.equal?(@export)
        raise ExportError, 'export may be called only once per Entrypoint'
      end

      @export = value
    end

    private

    # `Ruby::Box#eval` does not switch the loading Box, so during a nested
    # Import `$LOADED_FEATURES` there would be the Importer's. A file loaded
    # in this Box reads this Box's and hands it back through an ivar, so
    # concurrent checks of a Shared Import take turns.
    def loaded_features
      @lock.synchronize do
        @box.eval("load #{LOADED_FEATURES.inspect}")
        @loaded_features
      ensure
        @loaded_features = nil
      end
    end

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
    # runs, including patches such as Zeitwerk's. Box methods run in the Box
    # that defined them, and `$LOAD_PATH` resolves to the Box of the file being
    # loaded, which during a nested Import is the Importer. So gem activation
    # runs from activate_gems.rb, required here, with this Box's own Carton
    # and RubyGems.
    def require_in_box(feature)
      @box.eval("require #{feature.inspect}")
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

    def add_load_path(path)
      load_path = @box.load_path
      load_path.unshift(path) unless load_path.include?(path)
    end
  end
end
