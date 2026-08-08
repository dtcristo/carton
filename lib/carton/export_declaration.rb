# frozen_string_literal: true

module Carton
  # The tagged declaration made by one of Carton's two export forms.
  class ExportDeclaration
    def self.absent
      new(:absent, nil)
    end

    def self.default(value)
      new(:default, value)
    end

    def self.namespace(values)
      new(:namespace, values.dup.freeze)
    end

    def initialize(kind, value)
      @kind = kind
      @value = value
      freeze
    end

    def declare(declaration)
      unless @kind == :absent
        raise 'only one export is allowed per imported file'
      end

      declaration
    end

    def public_surface(bare:)
      case @kind
      when :absent
        bare
      when :default
        @value
      when :namespace
        yield(@value)
      end
    end

    private_class_method :new
  end
end
