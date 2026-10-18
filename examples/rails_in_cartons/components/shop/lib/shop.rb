# frozen_string_literal: true

# The composition root: assembles the Rails application from domain Cartons.
require 'logger' # Rails' own `require 'logger'` ran in the framework Box only

Framework = import 'framework'
Customers = import 'customers'
Orders = import 'orders'

# Let Rails resolve the domains' controllers and models by name.
Framework.register(Customers, Orders)

class Shop < Framework::Rails::Application
  config.root = File.expand_path('..', __dir__) # config/database.yml lives here
  config.load_defaults 8.1
  config.api_only = true
  config.eager_load = false
  config.logger = Logger.new(nil)
  config.secret_key_base = 'example'
  config.hosts.clear

  routes.append do
    resources :customers, only: %i[index create]
    resources :orders, only: %i[index create]
  end
end

Shop.initialize!

connection = Framework::ActiveRecord::Base.connection
Customers.create_schema(connection)
Orders.create_schema(connection)

# The application is a Rack app; only it crosses back to the importer.
export Shop
