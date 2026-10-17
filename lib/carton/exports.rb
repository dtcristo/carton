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

    # A lowercase export becomes a singleton method, so one named like a
    # method every `Carton::Exports` has, such as `fetch` or `name`, would
    # hide it. Capitalized names become constants and never collide.
    def self.reserved?(name)
      name = name.to_s
      !name.match?(/\A[A-Z]/) && RESERVED.include?(name)
    end

    # Raise for the first reserved name in `names`.
    def self.check_names(names)
      name = names.find { |n| reserved?(n) } or return

      raise ExportError,
            "export name #{name} would hide Carton::Exports##{name}: " \
              'rename it, or export it inside a Default Export'
    end

    def initialize(methods = {}, values = {})
      super()
      Exports.check_names(methods.keys + values.keys)
      @lookup = {}
      define_methods(methods)
      define_values(values)
    end

    def deconstruct_keys(keys)
      return super if keys

      to_h
    end

    # `#<Carton::Exports PI, add>`: the exported names, so a namespace is
    # recognizable in a console.
    def inspect
      names = @lookup.keys.join(', ')
      names.empty? ? '#<Carton::Exports>' : "#<Carton::Exports #{names}>"
    end
    alias to_s inspect

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

    def lookup_names = @lookup.keys

    RESERVED = public_instance_methods.map(&:to_s).freeze
    private_constant :RESERVED
  end
end
