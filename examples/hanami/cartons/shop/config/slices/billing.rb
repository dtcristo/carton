# frozen_string_literal: true

module BillingBoot
  Framework = import 'framework'
  Billing = import 'billing'

  Framework.register(Billing)
end
