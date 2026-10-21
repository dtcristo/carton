# frozen_string_literal: true

module Billing
  Invoice =
    Data.define(:id, :customer_id, :subtotal_cents, :tax_cents) do
      def to_h
        super.merge(total_cents: subtotal_cents + tax_cents)
      end
    end
end
