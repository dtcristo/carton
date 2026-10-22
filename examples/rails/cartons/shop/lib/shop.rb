# frozen_string_literal: true

require 'carton'
require 'logger'

# Carton boundary: import inside the app namespace, since Rake also defines a
# top-level `import`.
module Shop
  Framework = import 'framework'
  Customers = import 'customers'
  Billing = import 'billing'
  Framework.register(Customers, Billing, self)
end

require_relative 'shop/application'
Shop::Application.initialize!

# Export: the Main Box receives the Rack application, not a Box.
export Shop::Application
