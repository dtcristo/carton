# frozen_string_literal: true

module Carton
  class Box < Ruby::Box
    include ExportMethods

    UNSET_EXPORT = Object.new.freeze
    private_constant :UNSET_EXPORT

    def initialize
      super
      @bundle_activated = false
      reset_export
    end

    private

    def configure_for_import(parent_box:, entrypoint:)
      purge_gem_load_path
      purge_gem_loaded_features
      inherit_load_path(parent_box)
      reset_export
      require_in_box(entrypoint)
      self
    end

    def require_in_box(feature)
      eval("require #{feature.inspect}")
    end

    def resolve_feature_path_in_box(feature)
      eval("$LOAD_PATH.resolve_feature_path(#{feature.inspect})")
    end

    def set_export(value)
      if export_set?
        raise RuntimeError, 'only one export is allowed per imported file'
      end

      @export = value
    end

    def export_set?
      !@export.equal?(UNSET_EXPORT)
    end

    def export_value
      @export
    end

    def reset_export
      @export = UNSET_EXPORT
    end

    def mark_bundle_activated
      @bundle_activated = true
    end

    def bundle_activated?
      @bundle_activated
    end

    def purge_gem_load_path
      load_path.reject! { |path| gem_path?(File.expand_path(path)) }
    end

    def purge_gem_loaded_features
      eval('$LOADED_FEATURES').reject! do |feature|
        gem_path?(File.expand_path(feature))
      end
    end

    def inherit_load_path(source_box)
      return self unless source_box.respond_to?(:load_path)

      source_box.load_path.each do |path|
        next unless inherit_path?(path)

        load_path << path unless load_path.include?(path)
      end

      self
    end

    def inherit_path?(path)
      expanded = File.expand_path(path)
      !gem_path?(expanded)
    end

    def gem_path?(path)
      gem_roots = Gem.path.map { |root| File.expand_path(root) }
      gem_roots.any? { |root| path == root || path.start_with?("#{root}/") } ||
        path.include?('/vendor/bundle/') || path.include?('/bundler/gems/')
    end

    def lookup_entry(key)
      name = key.to_s

      if name.match?(/\A[A-Z]/)
        lookup_constant_entry(name)
      else
        lookup_method_entry(name)
      end
    end

    def lookup_constant_entry(name)
      [true, const_get(name)]
    rescue NameError
      [false, nil]
    end

    def lookup_method_entry(name)
      [true, eval(name)]
    rescue NameError, NoMethodError
      begin
        [true, __send__(name)]
      rescue NoMethodError
        [false, nil]
      end
    end
  end
end
