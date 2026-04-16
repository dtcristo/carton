# frozen_string_literal: true

module Carton
  module Runtime
    ENTRYPOINT = File.expand_path('../carton.rb', __dir__)
    private_constant :ENTRYPOINT

    module_function

    def import(path, base_dir:)
      box = build_import_box
      target = resolve_import_target(box, path, base_dir:)
      box.__send__(:activate_bundle_if_configured) if target == path
      box.__send__(:require_in_box, target)
      extract_export(box)
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
      parent_box = Ruby::Box.current
      box = Carton::Box.new
      bundle_gemfile = parent_box.eval("ENV['BUNDLE_GEMFILE']")
      box.__send__(
        :configure_for_import,
        parent_box:,
        entrypoint: ENTRYPOINT,
        bundle_gemfile:,
      )
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

    def resolve_import_target(box, path, base_dir:)
      expanded = File.expand_path(path, base_dir)
      return expanded if File.file?(expanded)

      expanded_rb = "#{expanded}.rb"
      return expanded_rb if File.file?(expanded_rb)

      resolved = box.__send__(:resolve_feature_path_in_box, path)
      return path unless resolved

      type, resolved_path = resolved
      return resolved_path if type == :rb && File.file?(resolved_path)

      path
    end
    private_class_method :resolve_import_target
  end
end
