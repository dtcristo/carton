# frozen_string_literal: true

# Carton boundary: the slice's code lives in the billing Carton; this file
# imports it instead of requiring a Second Copy.
module BillingBoot
  Framework = import 'framework'
  Billing = import 'billing'

  Framework.register(Billing)
end
