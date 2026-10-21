# frozen_string_literal: true

module CustomerBoot
  Framework = import_relative '../../lib/framework'
  Customers = import_relative '../../slices/customers'
  Framework.register(Customers)
end
