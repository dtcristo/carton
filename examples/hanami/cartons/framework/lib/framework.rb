# frozen_string_literal: true

require 'carton'

# The framework's gems and singleton registries live in this Carton.
require 'hanami'
require 'hanami/db/relation'
require 'hanami/db/repo'
require 'dry/validation'
require 'dry/operation'

module Framework
  Hanami = ::Hanami
  Dry = ::Dry

  # Hanami resolves slice namespaces here. Bind them explicitly; never copy
  # their classes into Object.
  def self.register(*namespaces)
    namespaces.each do |namespace|
      name = namespace.name
      if Object.const_defined?(name, false)
        unless Object.const_get(name, false).equal?(namespace)
          raise ArgumentError, "namespace already registered: #{name}"
        end
      else
        Object.const_set(name, namespace)
      end
    end
  end

  def self.cli(argv, script:)
    $PROGRAM_NAME = script
    ARGV.replace(argv)
    Ruby::Box.current.require_relative 'framework/cli'
  end

  def self.prepare
    # Anchor deferred framework requires in the framework Box during nested Imports.
    Ruby::Box.current.require_relative 'framework/prepare'
  end
end

# Export: shared Hanami and Dry modules and the registration and CLI helpers.
export Framework
