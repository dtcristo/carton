# frozen_string_literal: true

module CustomerBoot
  Framework = import 'framework'
  Customers = import 'customers'

  Framework.register(Customers)
end
