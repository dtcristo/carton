# frozen_string_literal: true

# Define import/export for ordinary gem consumers too.
require 'carton'

module Billing
  # A declared dependency, imported by gem name. Every importer of `pricing`
  # shares this one Carton.
  Pricing = import 'pricing'

  def self.invoice(number, prices)
    "Invoice #{number}: #{Pricing.total(prices).to_s('F')}"
  end
end

export Billing
