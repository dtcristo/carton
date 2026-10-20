# frozen_string_literal: true

module Billing
  class InvoiceRepository
    def create(customer_id:, subtotal_cents:, tax_cents:)
      InvoiceRecord.create!(customer_id:, subtotal_cents:, tax_cents:).id
    end

    def fetch(id)
      record = InvoiceRecord.find(id)
      {
        id: record.id,
        customer_id: record.customer_id,
        subtotal_cents: record.subtotal_cents,
        tax_cents: record.tax_cents,
      }
    end
  end
end
