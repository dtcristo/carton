# frozen_string_literal: true

module Billing
  class IssueInvoice
    def initialize(invoices:, customers:)
      @invoices = invoices
      @customers = customers
    end

    def call(customer_id:, subtotal_cents:)
      customer = @customers.fetch(customer_id)
      invoice = Invoice.new(customer_id: customer.id, subtotal_cents:)
      id =
        @invoices.create(
          customer_id: customer.id,
          subtotal_cents:,
          tax_cents: invoice.tax_cents,
        )
      Invoice.new(
        id:,
        customer_id: customer.id,
        subtotal_cents:,
        tax_cents: invoice.tax_cents,
      )
    end
  end
end
