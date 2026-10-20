# frozen_string_literal: true

require 'carton'
require 'logger'

# Import inside the app namespace: Rake also defines top-level `import`.
module Shop
  Framework = import 'framework'
  Customers = import 'customers'
  Orders = import 'orders'
  Framework.register(Customers, Orders, self)
end

require_relative 'shop/application'
Shop::Application.initialize!

# The Main Box receives the Rack application, not a Box.
export Shop::Application
