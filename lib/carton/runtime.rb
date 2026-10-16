# frozen_string_literal: true

module Carton
  module Runtime
    ENTRYPOINT = File.expand_path('../carton.rb', __dir__)
    private_constant :ENTRYPOINT
    # Used only when this Box is the Main Box. Carton Boxes reuse the Main
    # Box cache, so every Carton is built by the Main Box loader.
    IMPORT_CACHE = ImportCache.new { |target| load_import(target) }
    private_constant :IMPORT_CACHE

    module_function

    # Load the target feature in a new box and return the exported value, or
    # the box itself if the target does not export anything. Each Entrypoint
    # loads once per process; later imports return the same value.
    # `base_dir` is given for `import_relative`; plain `import` searches the
    # caller Box's `$LOAD_PATH`.
    def import(path, base_dir: nil)
      caller_box = Ruby::Box.current
      load_path = caller_box.eval('$LOAD_PATH.to_a')
      target = Resolver.resolve(path, load_path:, base_dir:)
      target.gems =
        GemActivation.closure(
          target.feature,
          caller_box.eval('defined?(Gem) ? Gem.loaded_specs : {}'),
        )
      import_cache.import(target)
    end

    # Declare an Export Namespace for the current carton. Symbols name
    # top-level methods; keyword arguments are plain values.
    def export(names, values, owner:)
      if (names.empty? && values.empty?) ||
           names.any? { |name| !name.is_a?(Symbol) }
        raise ArgumentError,
              'export takes method names and keyword arguments; use export_default for a single export'
      end

      duplicate = names.find { |name| values.key?(name) }
      if duplicate
        raise ArgumentError, "export name given more than once: #{duplicate}"
      end

      box = current_import_box
      methods = names.to_h { |name| [name, owner.method(name)] }
      box.__send__(
        :declare_export,
        ExportDeclaration.namespace(methods, values),
      )
      values
    end

    # Export a single value from the current carton.
    def export_default(value)
      current_import_box.__send__(
        :declare_export,
        ExportDeclaration.default(value),
      )
      value
    end

    def load_import(target)
      box = Carton::Box.new
      box.__send__(
        :configure_for_import,
        entrypoint: ENTRYPOINT,
        import_cache: IMPORT_CACHE,
      )
      box.__send__(
        :load_import,
        target.feature,
        load_path: target.load_path,
        gems: target.gems,
      )
      extract_export(box)
    end
    private_class_method :load_import

    def import_cache
      box = Ruby::Box.current
      return IMPORT_CACHE unless box.respond_to?(:import_cache, true)

      box.__send__(:import_cache)
    end
    private_class_method :import_cache

    def extract_export(box)
      box.__send__(:export_public_surface) do |methods, values|
        Carton::Exports.new(methods, values)
      end
    end
    private_class_method :extract_export

    # `export` and `export_default` only make sense while Carton is loading a
    # file inside an import box.
    def current_import_box
      box = Ruby::Box.current

      unless box.respond_to?(:declare_export, true)
        raise 'export/export_default must be called from inside Carton.import/import_relative'
      end

      box
    end
    private_class_method :current_import_box
  end
end
