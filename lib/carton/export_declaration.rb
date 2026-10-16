# frozen_string_literal: true

module Carton
  # The Export Namespace an Entrypoint builds from one or more `export` calls.
  # Each call adds names; a name may be exported only once. `default` is the
  # reserved name of the Default Export, as in ES modules.
  class ExportDeclaration
    def self.absent
      new({}, {}, declared: false)
    end

    def initialize(methods, values, declared:)
      @methods = methods.freeze
      @values = values.freeze
      @declared = declared
      freeze
    end

    def add(methods, values)
      duplicate =
        (methods.keys + values.keys).find do |name|
          @methods.key?(name) || @values.key?(name)
        end
      if duplicate
        raise ArgumentError, "export name given more than once: #{duplicate}"
      end

      self.class.__send__(
        :new,
        @methods.merge(methods),
        @values.merge(values),
        declared: true,
      )
    end

    # The Default Export when one was declared. Otherwise yields methods and
    # values for the Export Namespace, or for a Bare Carton's surface, which
    # `bare` computes lazily, when nothing was exported.
    def public_surface(bare:)
      return @values[:default] if @values.key?(:default)

      @declared ? yield(@methods, @values) : yield(*bare.call)
    end

    private_class_method :new
  end
end
