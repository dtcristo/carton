# frozen_string_literal: true

require 'carton'

module Shop
  # Carton boundary: Hanami comes from the framework Carton's Export.
  Framework = import 'framework'
  Hanami = Framework::Hanami

  Framework.register(self)

  private_constant :Framework, :Hanami

  require_relative '../config/app'
  Framework.prepare
end

# Export: Main receives an ordinary Rack application; it never loads Hanami.
export Shop::App
