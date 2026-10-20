# frozen_string_literal: true

module Shop
  class Application < Framework::Rails::Application
    config.root = File.expand_path('../..', __dir__)
    config.load_defaults 8.1
    config.api_only = true
    config.enable_reloading = false # Cartons load once; restart after edits.
    config.eager_load = ENV['RAILS_EAGER_LOAD'] == 'true'
    config.logger = Logger.new($stdout)
    config.log_level = :warn
    config.secret_key_base = 'carton-example-development-secret'
    config.hosts = %w[localhost 127.0.0.1 www.example.com example.org]

    # Use the Engines' real migrations directly, without copying or creating
    # tables while importing application code.
    config.paths['db/migrate'] = [
      Customers::Engine.root.join('db/migrate').to_s,
      Billing::Engine.root.join('db/migrate').to_s,
    ]
  end
end
