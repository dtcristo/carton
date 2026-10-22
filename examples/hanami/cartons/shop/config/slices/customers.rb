# frozen_string_literal: true

# Carton boundary: the slice's code lives in the customers Carton; this file
# imports it instead of requiring a Second Copy.
module CustomersBoot
  Framework = import 'framework'
  Customers = import 'customers'

  Framework.register(Customers)
end
