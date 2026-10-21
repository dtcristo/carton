# frozen_string_literal: true

module Shop
  class App < Hanami::App
    config.root = File.expand_path('..', __dir__)
    config.middleware.use :body_parser, :json
    environment(:test) do
      config.logger.stream = config.root.join('log/test.log').to_s
    end
    # Carton Entrypoints in lib/ must never be required as Second Copies.
    autoloader.ignore(config.root.join('lib'))
  end
end
