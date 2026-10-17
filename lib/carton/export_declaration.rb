# frozen_string_literal: true

module Carton
  # What an Entrypoint exports: an Export Namespace built from one or more
  # `export` calls, or a single Default Export from `export_default`. The two
  # forms are exclusive, and a name may be exported only once.
  class ExportDeclaration
    COMBINED =
      'export_default cannot be combined with export; ' \
        'put the other names inside the default value'
    private_constant :COMBINED

    NO_DEFAULT = Object.new.freeze
    private_constant :NO_DEFAULT

    def self.absent
      new({}, {}, NO_DEFAULT)
    end

    def initialize(methods, values, default)
      @methods = methods.freeze
      @values = values.freeze
      @default = default
      freeze
    end

    def add(methods, values)
      raise ExportError, COMBINED if default?

      Exports.check_names(methods.keys + values.keys)
      duplicate =
        (methods.keys + values.keys).find do |name|
          @methods.key?(name) || @values.key?(name)
        end
      if duplicate
        raise ExportError, "export name given more than once: #{duplicate}"
      end

      self.class.__send__(
        :new,
        @methods.merge(methods),
        @values.merge(values),
        NO_DEFAULT,
      )
    end

    def default(value)
      if default?
        raise ExportError, 'export_default may be called only once per file'
      end
      raise ExportError, COMBINED if namespace?

      self.class.__send__(:new, @methods, @values, value)
    end

    # The Default Export, or yields methods and values for the Export
    # Namespace, or for a Bare Carton's surface, which `bare` computes lazily,
    # when nothing was exported.
    def public_surface(bare:)
      return @default if default?

      namespace? ? yield(@methods, @values) : yield(*bare.call)
    end

    private_class_method :new

    private

    def default? = !NO_DEFAULT.equal?(@default)

    def namespace? = !(@methods.empty? && @values.empty?)
  end
end
