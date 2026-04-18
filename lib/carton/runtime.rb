# frozen_string_literal: true

module Carton
  module Runtime
    ENTRYPOINT = File.expand_path('../carton.rb', __dir__)
    private_constant :ENTRYPOINT
    ImportTarget = Struct.new(:feature, :load_path, keyword_init: true)
    private_constant :ImportTarget

    module_function

    def import(path, base_dir:)
      previous_loaded_specs = Gem.loaded_specs.dup
      target = resolve_import_target(path, base_dir:)
      box = build_import_box
      box.__send__(:add_import_load_path, target.load_path) if target.load_path
      box.__send__(:require_in_box, target.feature)
      extract_export(box)
    ensure
      if previous_loaded_specs && box&.__send__(:rubygems_bootstrapped?)
        Gem.loaded_specs.replace(previous_loaded_specs)
      end
    end

    def export(args, kwargs)
      if args.any? || kwargs.empty?
        raise ArgumentError,
              'export takes keyword arguments; use export_default for a single export'
      end

      current_import_box.__send__(:set_export, kwargs)
    end

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

    def current_import_box
      box = Ruby::Box.current

      unless box.respond_to?(:set_export, true)
        raise RuntimeError,
              'export/export_default must be called from inside Carton.import/import_relative'
      end

      box
    end
    private_class_method :current_import_box

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
