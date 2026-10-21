# frozen_string_literal: true

module Billing
  module TaxPolicy
    # Ten percent, rounded half up without floating point arithmetic.
    def self.call(subtotal_cents)
      (subtotal_cents + 5) / 10
    end
  end
end
