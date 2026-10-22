# frozen_string_literal: true

module Carton
  module Runtime
    # Used only when this Box is the Main Box. Carton Boxes reuse the Main
    # Box cache, so every Carton is built by the Main Box loader.
    IMPORT_CACHE =
      ImportCache.new do |target, gems:, locked_gems:|
        Box.new(IMPORT_CACHE).import(target, gems:, locked_gems:)
      end
    private_constant :IMPORT_CACHE

    module_function

    # Load the target in a new Carton Box and return its Export. Each Entrypoint
    # loads once per process; later imports return the same value. `base_dir` is
    # given for `import_relative`; plain `import` searches the Importer's
    # `$LOAD_PATH`, and `from` names the calling file for its error message.
    def import(path, base_dir: nil, from: nil)
      unless Ruby::Box.enabled?
        raise ImportError, 'Carton needs Ruby::Box: run Ruby with RUBY_BOX=1'
      end

      importer_box = Ruby::Box.current
      load_path = importer_box.eval('$LOAD_PATH.to_a')
      target = Resolver.resolve(path, load_path:, base_dir:)
      unless File.absolute_path?(target.feature)
        raise LoadError, missing_name_message(path, from)
      end

      loaded_specs = importer_box.eval('defined?(Gem) ? Gem.loaded_specs : {}')
      gems = GemActivation.closure(target.feature, loaded_specs)
      locked_gems =
        (GemActivation.locked(importer_box, loaded_specs) unless gems.empty?)
      import_cache.import(target, gems:, locked_gems:).export
    end

    # Make `value` the current Carton's Export, which `import` returns as
    # is. A Symbol is refused even outside the Entrypoint: `export def name`
    # and `export :Name` would export the Symbol itself.
    def export(value, file:)
      if value.is_a?(Symbol)
        raise ExportError,
              "export takes the value to export, not a name like #{value.inspect}: " \
                'export a module, or keywords for a Hash'
      end

      entrypoint_box(file)&.declare_export(value)
      value
    end

    # A name not on `$LOAD_PATH` is the usual mistake of `import` for a file
    # beside the calling file, so point at `import_relative` when one is there.
    def missing_name_message(path, from)
      message =
        "cannot load such file -- #{path}: import searches $LOAD_PATH, like require"
      return message unless from

      dir = File.dirname(from)
      file = Resolver.locate(path, load_path: [], base_dir: dir).feature
      "#{message}; use import_relative #{path.to_s.inspect} for #{file}"
    rescue LoadError
      message
    end
    private_class_method :missing_name_message

    def import_cache
      Box.for(Ruby::Box.current)&.import_cache || IMPORT_CACHE
    end
    private_class_method :import_cache

    # The Carton Box whose Entrypoint is `file`, or nil. Outside that file,
    # such as under a plain `require`, `export` is inert, so Carton-aware
    # files and gems still load the ordinary way.
    def entrypoint_box(file)
      box = Box.for(Ruby::Box.current)
      box if box&.entrypoint?(file)
    end
    private_class_method :entrypoint_box
  end
end
