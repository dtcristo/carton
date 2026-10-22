# frozen_string_literal: true

# Define import/export for ordinary gem consumers too.
require 'carton'

module Billing
  # Carton boundary: pricing is an Imported Carton, declared in billing's
  # gemspec. Every Importer receives the same Export.
  Pricing = import 'pricing'

  def self.invoice(number, prices)
    "Invoice #{number}: #{format('%.2f', Pricing.total(prices))}"
  end
end

# Export: the Carton's root module.
export Billing
