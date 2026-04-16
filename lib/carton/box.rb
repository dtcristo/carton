# frozen_string_literal: true

module Carton
  class Box < Ruby::Box
    include ExportMethods

    UNSET_EXPORT = Object.new.freeze
    private_constant :UNSET_EXPORT

    def initialize
      super
      reset_export
    end

    private

    def configure_for_import(parent_box:, entrypoint:, bundle_gemfile:)
      inherit_load_path(parent_box)
      reset_export
      require_in_box(entrypoint)
      set_bundle_gemfile(bundle_gemfile)
      self
    end

    def require_in_box(feature)
      eval("require #{feature.inspect}")
    end

    def resolve_feature_path_in_box(feature)
      eval("$LOAD_PATH.resolve_feature_path(#{feature.inspect})")
    end

    def activate_bundle_if_configured
      gemfile = ENV['BUNDLE_GEMFILE']
      return unless gemfile && File.file?(gemfile)

      require_in_box('bundler/setup')
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

    def set_bundle_gemfile(path)
      return unless path

      eval("ENV['BUNDLE_GEMFILE'] = #{path.inspect}")
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
