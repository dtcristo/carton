# frozen_string_literal: true

module Shop
  class App < Hanami::App
    config.root = File.expand_path('..', __dir__)
    config.middleware.use :body_parser, :json

    # The parser runs before actions, so handle invalid JSON at the app boundary.
    config.render_errors = true
    config.render_error_responses[
      'Hanami::Middleware::BodyParser::BodyParsingError'
    ] = :bad_request

    environment(:test) do
      config.logger.stream = config.root.join('log/test.log').to_s
    end

    # Carton Entrypoints in lib/ must never be required as Second Copies.
    autoloader.ignore(config.root.join('lib'))
  end
end
