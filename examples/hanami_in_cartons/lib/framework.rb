# frozen_string_literal: true

require 'carton'
# The framework's gems and singleton registries live in this Carton.
Carton.setup_bundle
require 'hanami'
require 'hanami/db/relation'
require 'hanami/db/repo'
require 'dry/validation'
require 'dry/operation'
module Framework
  Hanami = ::Hanami
  Dry = ::Dry
  def self.register(namespace)
    name = namespace.name
    if Object.const_defined?(name, false)
      unless Object.const_get(name, false).equal?(namespace)
        raise ArgumentError, "namespace already registered: #{name}"
      end
    else
      Object.const_set(name, namespace)
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
export Framework
