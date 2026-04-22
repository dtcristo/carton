# frozen_string_literal: true

module Carton
  module Runtime
    ENTRYPOINT = File.expand_path('../carton.rb', __dir__)
    private_constant :ENTRYPOINT
    ImportTarget = Struct.new(:feature, :load_path, keyword_init: true)
    private_constant :ImportTarget

    module_function

    # Build a fresh box, load the target feature inside it, and return the
    # exported value. If the target does not export anything, return the box.
    def import(path, base_dir:)
      target = resolve_import_target(path, base_dir:)
      box = build_import_box
      box.__send__(:load_import, target.feature, load_path: target.load_path)
      extract_export(box)
    end

    # Export a small named surface from the current carton.
    def export(args, kwargs)
      if args.any? || kwargs.empty?
        raise ArgumentError,
              'export takes keyword arguments; use export_default for a single export'
      end

      current_import_box.__send__(:set_export, kwargs)
    end

    # Export a single value from the current carton.
    def export_default(value)
      current_import_box.__send__(:set_export, value)
    end

    def build_import_box
      box = Carton::Box.new
      box.__send__(:configure_for_import, entrypoint: ENTRYPOINT)
      box
    end
    private_class_method :build_import_box

    def extract_export(box)
      return box unless box.__send__(:export_set?)

      value = box.__send__(:export_value)
      value.is_a?(Hash) ? Carton::Exports.new(value) : value
    end
    private_class_method :extract_export

    # `export` and `export_default` only make sense while Carton is loading a
    # file inside an import box.
    def current_import_box
      box = Ruby::Box.current

      unless box.respond_to?(:set_export, true)
        raise 'export/export_default must be called from inside Carton.import/import_relative'
      end

      box
    end
    private_class_method :current_import_box

    # Resolve the import the same way Ruby would resolve a regular `require` in
    # the caller box, then carry only the matched load-path root into the new
    # import box when the target was found by name.
    def resolve_import_target(path, base_dir:)
      expanded = File.expand_path(path, base_dir)
      return ImportTarget.new(feature: expanded) if File.file?(expanded)

      expanded_rb = "#{expanded}.rb"
      return ImportTarget.new(feature: expanded_rb) if File.file?(expanded_rb)

      resolved =
        Ruby::Box.current.eval(
          "$LOAD_PATH.resolve_feature_path(#{path.inspect})",
        )
      return ImportTarget.new(feature: path) unless resolved

      type, resolved_path = resolved
      if type == :rb && File.file?(resolved_path)
        return(
          ImportTarget.new(
            feature: resolved_path,
            load_path: resolve_import_load_path(path, resolved_path),
          )
        )
      end

      ImportTarget.new(feature: path)
    end
    private_class_method :resolve_import_target

    # When a name-based import resolved through a specific caller load-path
    # entry, seed only that entry into the imported box instead of copying the
    # whole caller `$LOAD_PATH` forward.
    def resolve_import_load_path(feature, resolved_path)
      load_paths = Ruby::Box.current.eval('$LOAD_PATH.to_a')

      load_paths.find do |path|
        expanded = File.expand_path(path)
        resolved_path == File.join(expanded, feature) ||
          resolved_path == File.join(expanded, "#{feature}.rb")
      end
    end
    private_class_method :resolve_import_load_path
  end
end
