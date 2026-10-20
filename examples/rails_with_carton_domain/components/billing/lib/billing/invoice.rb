# frozen_string_literal: true

module Billing
  # Plain Ruby domain object, eager loaded by the Carton's Zeitwerk loader
  # in the Carton's Box.
  class Invoice
    def initialize(id:, subtotal_cents:)
      @id = id
      @subtotal_cents = subtotal_cents
    end

    def total_cents = @subtotal_cents + TaxPolicy.tax_cents(@subtotal_cents)

    def to_h = { id: @id, subtotal_cents: @subtotal_cents, total_cents: }
  end
end
