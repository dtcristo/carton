# frozen_string_literal: true

module Billing
  # Plain Ruby domain object, eager loaded by the Carton's Zeitwerk loader
  # in the Carton's Box.
  class Invoice
    attr_reader :id, :customer_id, :subtotal_cents, :tax_cents

    def initialize(customer_id:, subtotal_cents:, id: nil, tax_cents: nil)
      unless subtotal_cents.is_a?(Integer) && subtotal_cents >= 0
        raise InvalidInvoice.new(
                subtotal_cents: ['must be a non-negative integer'],
              )
      end

      @id = id
      @customer_id = customer_id
      @subtotal_cents = subtotal_cents
      @tax_cents = tax_cents || TaxPolicy.call(subtotal_cents)
      unless @tax_cents.is_a?(Integer) && @tax_cents >= 0
        raise InvalidInvoice.new(tax_cents: ['must be a non-negative integer'])
      end

      freeze
    end

    def total_cents = subtotal_cents + tax_cents

    def to_h = { id:, customer_id:, subtotal_cents:, tax_cents:, total_cents: }
  end
end
