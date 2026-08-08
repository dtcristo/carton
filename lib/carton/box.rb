# frozen_string_literal: true

module Carton
  class Box < Ruby::Box
    include ExportMethods

    def initialize
      # `require "bundler/setup"` leaves process-global `BUNDLER_SETUP` set so a
      # later RubyGems load can re-enter setup. Optional Boxes copy Master, so
      # Bundler is undefined there and that hook would re-run the caller's
      # bundle. Clear it only around box construction.
      previous_bundler_setup = ENV.delete('BUNDLER_SETUP')
      begin
        super
      ensure
        ENV['BUNDLER_SETUP'] = previous_bundler_setup if previous_bundler_setup
      end
      @rubygems_bootstrapped = false
      reset_export_declaration
    end

    def key?(key)
      find_public_entry(key).first
    end

    alias has_key? key?

    private

    # Fresh boxes inherit root-box gem paths and loaded features. Strip those
    # inherited gem entries, then load Carton's own entrypoint so the imported
    # file gets `import`, `import_relative`, and `export`.
    def configure_for_import(entrypoint:)
      purge_gem_load_path
      purge_gem_loaded_features
      reset_export_declaration
      add_import_load_path(File.dirname(entrypoint))
      require_in_box(entrypoint)
      snapshot_import_support
      self
    end

    # Load the target feature inside the box. If the target bootstrapped
    # RubyGems, restore the caller's loaded-spec view after the import. This is
    # a temporary RubyGems isolation hack, not part of Carton's core box model.
    def load_import(feature, load_path: nil)
      add_import_load_path(load_path) if load_path

      result = preserve_loaded_specs { require_in_box(feature) }
      discover_public_entries
      result
    end

    def require_in_box(feature)
      eval("require #{feature.inspect}")
    end

    def add_import_load_path(path)
      load_path.unshift(path) unless load_path.include?(path)
    end

    def declare_export(declaration)
      @export_declaration = @export_declaration.declare(declaration)
    end

    def export_public_surface(&)
      @export_declaration.public_surface(bare: self, &)
    end

    def reset_export_declaration
      @export_declaration = ExportDeclaration.absent
    end

    def mark_rubygems_bootstrapped
      @rubygems_bootstrapped = true
    end

    def rubygems_bootstrapped?
      @rubygems_bootstrapped
    end

    def preserve_loaded_specs
      previous_loaded_specs = Gem.loaded_specs.dup
      yield
    ensure
      if previous_loaded_specs && rubygems_bootstrapped?
        Gem.loaded_specs.replace(previous_loaded_specs)
      end
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
      found, entry = find_public_entry(key)
      return false, nil unless found

      entry.is_a?(Method) ? [true, entry.call] : [true, const_get(entry, false)]
    end

    def find_public_entry(key)
      return false, nil unless key.is_a?(String) || key.is_a?(Symbol)

      name = key.to_s
      return true, name if @public_constant_names.include?(name)

      method_entry = @public_method_entries[name]
      method_entry ? [true, method_entry] : [false, nil]
    end

    def snapshot_import_support
      @import_constant_names = constants(false).map(&:to_s)
      @import_method_names = top_level_methods.keys
    end

    def discover_public_entries
      @public_constant_names =
        constants(false).map(&:to_s) - @import_constant_names
      @public_method_entries = top_level_methods.except(*@import_method_names)
    end

    def top_level_methods
      eval(
        'Object.private_instance_methods(false).to_h { |name| [name.to_s, method(name)] }',
      )
    end
  end
end
