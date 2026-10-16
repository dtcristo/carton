# frozen_string_literal: true

module Carton
  # Module-like wrapper returned from named exports.
  #
  # Exported methods become singleton methods that forward to the carton's
  # method. Capitalized value keys become constants; lowercase value keys become
  # readers that return the value as-is. Lookup helpers return the `Method`
  # object or the value.
  class Exports < ::Module
    include ExportMethods

    def initialize(methods = {}, values = {})
      super()
      @lookup = {}
      define_methods(methods)
      define_values(values)
    end

    def deconstruct_keys(keys)
      return super if keys

      @lookup.to_h { |key, value| [key.to_sym, value] }
    end

    private

    def define_methods(methods)
      methods.each do |name, method|
        @lookup[name.to_s] = method
        define_singleton_method(name) do |*args, **kwargs, &block|
          method.call(*args, **kwargs, &block)
        end
      end
    end

    def define_values(values)
      values.each do |key, value|
        @lookup[key.to_s] = value

        if key.to_s.match?(/\A[A-Z]/)
          const_set(key, value)
        else
          define_singleton_method(key) { value }
        end
      end
    end

    def lookup_entry(key)
      name = key.to_s
      @lookup.key?(name) ? [true, @lookup[name]] : [false, nil]
    end
  end
end
