# frozen_string_literal: true

# This injected object's methods run in Main, beside Active Record. Only
# integer IDs and invoice attributes cross into or out of the Billing Carton.
class InvoiceRepository
  def create(customer_id:, subtotal_cents:, tax_cents:)
    Invoice.create!(customer_id:, subtotal_cents:, tax_cents:).id
  end

  def fetch(id)
    invoice = Invoice.find(id)
    {
      id: invoice.id,
      customer_id: invoice.customer_id,
      subtotal_cents: invoice.subtotal_cents,
      tax_cents: invoice.tax_cents,
    }
  end
end
