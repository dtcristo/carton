# frozen_string_literal: true

module BillingBoot
  Framework = import_relative '../../lib/framework'
  Billing = import_relative '../../slices/billing'

  Framework.register(Billing)
end
