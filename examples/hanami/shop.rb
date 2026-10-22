# frozen_string_literal: true

require 'carton'

Carton.setup_bundle

module Shop
  Framework = import_relative 'lib/framework'
  Hanami = Framework::Hanami

  Framework.register(self)

  private_constant :Framework, :Hanami

  require_relative 'config/app'
  Framework.prepare
end

# Main receives an ordinary Rack application; it never loads Hanami.

export Shop::App
