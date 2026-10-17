# frozen_string_literal: true

# Inside the billing Carton, so it can only be loaded by billing.rb.
module Billing
  Invoice = Struct.new(:subtotal, :tax) { def total = subtotal + tax }
end
