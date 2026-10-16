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
      loaded_specs = caller_box.eval('defined?(Gem) ? Gem.loaded_specs : {}')
      target.gems = GemActivation.closure(target.feature, loaded_specs)
      unless target.gems.empty?
        target.locked_gems = GemActivation.locked(caller_box, loaded_specs)
      end
      import_cache.import(target)
    end

    # Add to the current carton's Export Namespace. A capitalized Symbol names
    # a top-level constant, any other Symbol a top-level method; keyword
    # arguments are plain values, and `default:` names the Default Export.
    # Like `private`, a single Symbol is returned so `export def name ...`
    # works.
    def export(names, values, owner:, file:)
      if (names.empty? && values.empty?) ||
           names.any? { |name| !name.is_a?(Symbol) }
        raise ArgumentError,
              'export takes Symbols naming methods or constants, and keyword values'
      end

      if names.include?(:default)
        raise ArgumentError,
              'export :default would export a method; use export default: value'
      end

      duplicate = (names + values.keys).tally.find { |_, count| count > 1 }
      if duplicate
        raise ArgumentError,
              "export name given more than once: #{duplicate.first}"
      end

      constants, method_names =
        names.partition { |name| name.match?(/\A[A-Z]/) }
      methods = method_names.to_h { |name| [name, owner.method(name)] }
      constants =
        constants.to_h { |name| [name, Object.const_get(name, false)] }
      entrypoint_box(file)&.__send__(
        :declare_export,
        methods,
        values.merge(constants),
      )
      names.first if names.size == 1 && values.empty?
    end

    def load_import(target)
      box = Box.new
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
        locked_gems: target.locked_gems,
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
        Exports.new(methods, values)
      end
    end
    private_class_method :extract_export

    # The Carton Box whose Entrypoint is `file`, or nil. Outside that file,
    # such as under a plain `require`, `export` is inert, so Carton-aware
    # files and gems still load the ordinary way.
    def entrypoint_box(file)
      box = Ruby::Box.current
      return unless box.respond_to?(:entrypoint?, true)

      box if box.__send__(:entrypoint?, file)
    end
    private_class_method :entrypoint_box
  end
end
