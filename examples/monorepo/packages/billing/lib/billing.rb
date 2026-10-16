# frozen_string_literal: true

module Billing
  # A declared dependency, imported by gem name. Every importer of `pricing`
  # shares this one Carton.
  Pricing = import 'pricing'

  def self.invoice(number, prices)
    "Invoice #{number}: #{Pricing.total(prices).to_s('F')}"
  end
end

export_default Billing
