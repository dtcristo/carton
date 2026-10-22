# frozen_string_literal: true

module CustomersBoot
  Framework = import 'framework'
  Customers = import 'customers'

  Framework.register(Customers)
end
