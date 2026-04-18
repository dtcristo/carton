# frozen_string_literal: true

module Carton
  class Box < Ruby::Box
    include ExportMethods

    UNSET_EXPORT = Object.new.freeze
    private_constant :UNSET_EXPORT

    def initialize
      super
      @rubygems_bootstrapped = false
      reset_export
    end

    private

    def configure_for_import(entrypoint:)
      purge_gem_load_path
      purge_gem_loaded_features
      reset_export
      add_import_load_path(File.dirname(entrypoint))
      require_in_box(entrypoint)
      self
    end

    def require_in_box(feature)
      eval("require #{feature.inspect}")
    end

    def add_import_load_path(path)
      load_path.unshift(path) unless load_path.include?(path)
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

    def mark_rubygems_bootstrapped
      @rubygems_bootstrapped = true
    end

    def rubygems_bootstrapped?
      @rubygems_bootstrapped
    end

    def purge_gem_load_path
      load_path.reject! { |path| gem_path?(File.expand_path(path)) }
    end

    def purge_gem_loaded_features
      eval('$LOADED_FEATURES').reject! do |feature|
        gem_path?(File.expand_path(feature))
      end
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
