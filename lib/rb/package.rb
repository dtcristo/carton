raise 'Ruby 4.0+ is required for Rb::Package' if RUBY_VERSION.to_f < 4.0

module Rb
  module Package
    # Define deconstruct_keys implementation that works in Box context
    DECONSTRUCT_KEYS_BODY = lambda do |keys|
      return {} unless keys

      keys.each_with_object({}) do |key, hash|
        name = key.to_s
        hash[key] = if name.match?(/\A[A-Z]/)
          begin
            const_get(name)
          rescue NameError
            next
          end
        else
          begin
            eval(name)
          rescue NameError, NoMethodError
            next
          end
        end
      end
    end

    def import(path)
      box = Ruby::Box.new
      box.require(__FILE__)

      # Resolve relative/absolute file paths; fall back to gem name lookup
      expanded = File.expand_path(path, Dir.pwd)
      if File.exist?(expanded) || File.exist?("#{expanded}.rb")
        box.require(expanded)
      else
        # Gem import: inject transitive load paths into the box first
        gem_require_paths(path).each do |p|
          box.eval("$LOAD_PATH << #{p.inspect}")
        end
        box.require(path)
      end

      # Check for Rb::Package::Exports module first
      begin
        exports_module = box.const_get(:"Rb").const_get(:"Package").const_get(:Exports)
        return exports_module
      rescue NameError
        # Fall back to EXPORT constant
        begin
          single_export = box.const_get(:"Rb").const_get(:"Package").const_get(:EXPORT)
          return single_export
        rescue NameError
          # Bare package/gem with no exports — return the Box instance directly
          # Inject deconstruct_keys for pattern matching support
          box.define_singleton_method(:deconstruct_keys, DECONSTRUCT_KEYS_BODY)
          return box
        end
      end
    end

    def export(*args, **kwargs)
      value =
        if kwargs.any? && args.empty?
          kwargs # Multiple exports
        elsif args.size == 1 && kwargs.empty?
          args.first # Single export
        else
          raise ArgumentError,
                'Export takes either a single object or keyword arguments'
        end

      # Create Rb::Package namespace in the box if it doesn't exist
      unless Object.const_defined?(:"Rb")
        Object.const_set(:Rb, Module.new)
      end
      rb_module = Object.const_get(:Rb)

      unless rb_module.const_defined?(:"Package")
        rb_module.const_set(:Package, Module.new)
      end
      package_module = rb_module.const_get(:Package)

      if value.is_a?(Hash)
        # Create Exports module for hash exports
        exports_module = Module.new

        value.each do |k, v|
          if k.to_s.match?(/^[A-Z]/)
            # Capitalized keys become Constants
            exports_module.const_set(k, v)
          else
            # Lowercase keys become Singleton Methods
            exports_module.define_singleton_method(k) do |*args, **kw, &blk|
              v.respond_to?(:call) ? v.call(*args, **kw, &blk) : v
            end
          end
        end

        # Attach deconstruct_keys to the Exports module
        exports_module.define_singleton_method(:deconstruct_keys) do |keys|
          keys ? value.slice(*keys) : value
        end

        # Set the Exports module on Rb::Package
        package_module.const_set(:Exports, exports_module)
      else
        # For single exports, set EXPORT constant
        package_module.const_set(:EXPORT, value)
      end
    end

    private

    def gem_require_paths(name, visited = Set.new)
      return [] if visited.include?(name)

      visited << name
      spec = Gem::Specification.find_by_name(name)
      paths = spec.full_require_paths.dup
      spec.runtime_dependencies.each do |dep|
        paths.concat(gem_require_paths(dep.name, visited))
      end
      paths
    rescue Gem::MissingSpecError
      []
    end
  end
end

# Inject the module into Kernel
Kernel.prepend(Rb::Package)
