# frozen_string_literal: true

require_relative 'boot'
require 'carton'
require 'rails'
require 'active_record/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'

module Shop
  class Application < Rails::Application
    config.load_defaults 8.1
    config.enable_reloading = false # Restart to pick up changed Cartons.
    config.eager_load = ENV['RAILS_EAGER_LOAD'] == 'true'
    config.logger = Logger.new($stdout)
    config.log_level = :warn
    config.secret_key_base = 'carton-example-development-secret'
    config.hosts = %w[localhost 127.0.0.1 www.example.com example.org]
  end
end
