raise 'Ruby 4.0+ is required for Rb::Package' if RUBY_VERSION.to_f < 4.0

module Rb
  module Package
    def self.inject_methods(obj, exports_map = nil, box = nil)
      # Use a local variable to capture exports_map in the closures
      exports_data = exports_map

      obj.define_singleton_method(:deconstruct_keys) do |keys|
        return {} unless keys

        keys.each_with_object({}) do |key, hash|
          name = key.to_s
          hash[key] = if exports_data
            exports_data[key.to_sym] || exports_data[key.to_s]
          elsif box
            if name.match?(/\A[A-Z]/)
              begin
                box.const_get(name)
              rescue NameError
                next
              end
            else
              begin
                box.eval(name)
              rescue NameError, NoMethodError
                next
              end
            end
          end
        end
      end

      obj.define_singleton_method(:fetch) do |*keys|
        key = keys.first
        name = key.to_s

        if exports_data
          exports_data[key.to_sym] || exports_data[key.to_s]
        elsif box
          if name.match?(/\A[A-Z]/)
            begin
              box.const_get(name)
            rescue NameError
              nil
            end
          else
            begin
              box.eval(name)
            rescue NameError, NoMethodError
              nil
            end
          end
        end
      end

      obj.define_singleton_method(:fetch_values) do |*keys|
        keys.map { |key| fetch(key) }
      end
    end

    def self.extract_exports(box)
      # Each box runs its own isolated copy of Rb::Package, so EXPORT and Exports
      # set by export() inside a box live in that box's namespace and do not leak
      # to any other box or to the outer module. We look up through the box.
      begin
        box::Rb::Package::Exports
      rescue NameError
        begin
          box::Rb::Package::EXPORT
        rescue NameError
          # Bare package/gem with no exports — return the Box instance directly
          inject_methods(box, nil, box)
          box
        end
      end
    end

    module Kernel
      def import(path)
        box = Ruby::Box.new
        box.require(__FILE__)

        # Seed the box's $LOAD_PATH from the caller's. When import is called from
        # within another box (e.g. after bundler/setup), $LOAD_PATH reflects that
        # box's load path, so gem and package paths are naturally inherited by the
        # child box. Each box has its own isolated $LOAD_PATH.
        $LOAD_PATH.each { |p| box.eval("$LOAD_PATH.unshift(#{p.inspect}) unless $LOAD_PATH.include?(#{p.inspect})") }

        expanded = File.expand_path(path, Dir.pwd)
        if File.exist?(expanded) || File.exist?("#{expanded}.rb")
          box.require(expanded)
        else
          box.require(path)
        end

        Rb::Package.extract_exports(box)
      end

      def import_relative(path)
        caller_dir = File.dirname(caller_locations(1, 1).first.path)
        absolute_path = File.expand_path(path, caller_dir)

        box = Ruby::Box.new
        box.require(__FILE__)

        # Propagate LOAD_PATH so nested imports within the loaded file can resolve
        # gems and packages by name (e.g. after bundler/setup in the caller's box).
        $LOAD_PATH.each { |p| box.eval("$LOAD_PATH.unshift(#{p.inspect}) unless $LOAD_PATH.include?(#{p.inspect})") }

        box.require(absolute_path)

        Rb::Package.extract_exports(box)
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

        if value.is_a?(Hash)
          # Create Exports module for hash exports
          exports_module = Module.new

          value.each do |k, v|
            if k.to_s.match?(/^[A-Z]/)
              exports_module.const_set(k, v)
            else
              exports_module.define_singleton_method(k) do |*args, **kw, &blk|
                v.respond_to?(:call) ? v.call(*args, **kw, &blk) : v
              end
            end
          end

          Rb::Package.inject_methods(exports_module, value)

          # Rb::Package::Exports does not leak between boxes — see extract_exports.
          Rb::Package.const_set(:Exports, exports_module)
        else
          # Rb::Package::EXPORT does not leak between boxes — see extract_exports.
          Rb::Package.const_set(:EXPORT, value)
        end
      end
    end
  end
end

# Inject only the Kernel module into Kernel
Kernel.prepend(Rb::Package::Kernel)
