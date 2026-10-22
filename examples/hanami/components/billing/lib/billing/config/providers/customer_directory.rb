# frozen_string_literal: true

Billing::Slice.register_provider(:customer_directory) do
  start do
    # An Import shares the existing Customers Carton; no class is required twice.
    customers = import 'customers'
    register 'customer_directory', customers::Slice['directory']
  end
end
