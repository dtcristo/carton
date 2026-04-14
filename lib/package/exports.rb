# frozen_string_literal: true

module Package
  class Exports < ::Module
    include ExportMethods

    def initialize(values = {})
      super()
      @values = values
      define_exports
    end

    private

    def define_exports
      @values.each do |key, value|
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
      if @values.key?(key.to_sym)
        [true, @values[key.to_sym]]
      elsif @values.key?(key.to_s)
        [true, @values[key.to_s]]
      else
        [false, nil]
      end
    end
  end
end
