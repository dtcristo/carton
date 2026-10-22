# frozen_string_literal: true

require 'carton'
require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'

require_relative '../app/models/application_record'
require_relative '../app/controllers/application_controller'

# Rails runs once here. Domains import these ordinary shared class objects.
module Framework
  Rails = ::Rails
  ActiveRecord = ::ActiveRecord
  ApplicationRecord = ::ApplicationRecord
  ApplicationController = ::ApplicationController
  BrowserController = ::ActionController::Base

  # Rails resolves qualified controller and association names here.
  # Bind namespaces explicitly; never copy their classes into Object.
  def self.register(*namespaces)
    namespaces.each do |namespace|
      name = namespace.name
      if Object.const_defined?(name, false)
        existing = Object.const_get(name, false)
        unless existing.equal?(namespace)
          raise ArgumentError, "namespace already registered: #{name}"
        end
      else
        Object.const_set(name, namespace)
      end
    end
  end

  # The example's CLI enters this Box before loading Rails commands and Rake.
  # APP_PATH is Rails' standard bootstrap constant, local to this Box.
  def self.cli(argv, application:)
    Object.const_set(:APP_PATH, application)
    ARGV.replace(argv)
    require 'rails/commands'
  end
end

export Framework
