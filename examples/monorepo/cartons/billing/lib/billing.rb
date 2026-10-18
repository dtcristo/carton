# frozen_string_literal: true

# Define import/export for ordinary gem consumers too.
require 'carton'

module Billing
  # Pricing is an Imported Carton, declared in billing's gemspec. Every
  # Importer receives the same Export.
  Pricing = import 'pricing'

  def self.invoice(number, prices)
    "Invoice #{number}: #{Pricing.total(prices).to_s('F')}"
  end
end

export Billing
