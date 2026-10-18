# frozen_string_literal: true

# The billing Carton: this Entrypoint plus everything in billing/. Its own
# files load with require_relative, inside this Carton's one Box.
require_relative 'billing/invoice'
require_relative 'billing/tax'

module Billing
  # Internal: Ruby's own visibility hides it from importers.
  private_constant :Tax

  def self.invoice(subtotal) = Invoice.new(subtotal, Tax.on(subtotal))
end

# The Default Export: importing billing returns this module.
export Billing
