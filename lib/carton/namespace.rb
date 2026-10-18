# frozen_string_literal: true

module Carton
  # What importing a Bare Carton returns: a module of the constants and
  # top-level helpers its Entrypoint defined. Helpers become singleton
  # methods that forward to the Carton's method, and lookup helpers return
  # the `Method` object or the constant.
  class Namespace < ::Module
    include NamespaceMethods

    # A helper becomes a singleton method, so one named like a method every
    # `Carton::Namespace` has, such as `fetch` or `name`, would hide it.
    # Constants are capitalized and never collide.
    def self.reserved?(name)
      name = name.to_s
      !name.match?(/\A[A-Z]/) && RESERVED.include?(name)
    end

    # Raise for the first reserved name in `names`.
    def self.check_names(names)
      name = names.find { |n| reserved?(n) } or return

      raise ExportError,
            "a top-level method named #{name} would hide " \
              "Carton::Namespace##{name}: rename it, or export a module"
    end

    def initialize(methods = {}, constants = {})
      super()
      Namespace.check_names(methods.keys)
      @lookup = {}
      define_methods(methods)
      define_constants(constants)
    end

    def deconstruct_keys(keys)
      return super if keys

      to_h
    end

    # `#<Carton::Namespace PI, add>`: its names, so a namespace is
    # recognizable in a console.
    def inspect
      names = @lookup.keys.join(', ')
      names.empty? ? '#<Carton::Namespace>' : "#<Carton::Namespace #{names}>"
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

    def define_constants(constants)
      constants.each do |name, value|
        @lookup[name.to_s] = value
        const_set(name, value)
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
