# frozen_string_literal: true

module Billing
  # Plain Ruby domain object, autoloaded by the Carton's Zeitwerk loader.
  class Invoice
    def initialize(id:, subtotal_cents:)
      @id = id
      @subtotal_cents = subtotal_cents
    end

    def total_cents = @subtotal_cents + TaxPolicy.tax_cents(@subtotal_cents)

    def to_h = { id: @id, subtotal_cents: @subtotal_cents, total_cents: }
  end
end
