# frozen_string_literal: true

# Standard Rails boot: Bundler sets up the app's gems in the Main Box.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup'
require 'carton'

require 'rails'
require 'action_controller/railtie'

module Shop
  class Application < Rails::Application
    # No config.ru here, so tell Rails where the app lives.
    config.root = File.expand_path('..', __dir__)
    config.load_defaults 8.1
    config.api_only = true
    config.eager_load = false
    config.logger = Logger.new(nil)
    config.secret_key_base = 'example'
    config.hosts.clear
  end
end
