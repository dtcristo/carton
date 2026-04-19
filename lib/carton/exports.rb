# frozen_string_literal: true

module Carton
  # Module-like wrapper returned from named exports.
  #
  # Capitalized keys become constants. Lowercase keys become singleton methods
  # or values addressable through the shared lookup helpers in `ExportMethods`.
  class Exports < ::Module
    include ExportMethods

    def initialize(values = {})
      super()
      @values = values
      @lookup = {}
      define_exports
    end

    private

    def define_exports
      @values.each do |key, value|
        @lookup[key.to_s] = value

        if key.to_s.match?(/\A[A-Z]/)
          const_set(key, value)
        else
          define_singleton_method(
            key,
          ) { |*args, **kwargs, &block| value.respond_to?(:call) ? value.call(*args, **kwargs, &block) : value }
        end
      end
    end

    def lookup_entry(key)
      name = key.to_s
      @lookup.key?(name) ? [true, @lookup[name]] : [false, nil]
    end
  end
end
