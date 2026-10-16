# frozen_string_literal: true

module Carton
  class Box < Ruby::Box
    include ExportMethods

    def initialize
      super
      reset_export_declaration
    end

    def key?(key)
      find_public_entry(key).first
    end

    alias has_key? key?

    def deconstruct_keys(keys)
      return super if keys

      helpers = @public_method_entries.transform_keys(&:to_sym)
      constants =
        @public_constant_names.to_h do |name|
          [name.to_sym, const_get(name, false)]
        end
      helpers.merge(constants)
    end

    private

    # Fresh boxes copy Master, so they start without the caller's gems. Load
    # Carton's own entrypoint so the imported file gets `import`,
    # `import_relative`, and `export`. Nested imports reuse the caller's
    # process-wide import cache.
    def configure_for_import(entrypoint:, import_cache:)
      @import_cache = import_cache
      reset_export_declaration
      add_import_load_path(File.dirname(entrypoint))
      require_in_box(entrypoint)
      snapshot_import_support
      self
    end

    # Activate the caller's gems for the target, then load it inside the box.
    def load_import(feature, load_path: nil, gems: [])
      activate_gems(gems) unless gems.empty?
      add_import_load_path(load_path) if load_path

      result = require_in_box(feature)
      discover_public_entries
      result
    end

    attr_reader :import_cache

    def require_in_box(feature)
      eval("require #{feature.inspect}")
    end

    # Box methods run in the Box that defined them, so call this Box's own
    # copy of Carton to activate gems in this Box's RubyGems.
    def activate_gems(gems)
      eval('Carton.const_get(:GemActivation)').activate(gems)
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

    def lookup_entry(key)
      found, entry = find_public_entry(key)
      return false, nil unless found

      entry.is_a?(Method) ? [true, entry] : [true, const_get(entry, false)]
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
