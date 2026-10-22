# frozen_string_literal: true

module Billing
  class InvoicesController < ApplicationController
    def create
      attributes = params.expect(invoice: %i[customer_id subtotal_cents])
      value = attributes[:subtotal_cents]
      # Form parameters are strings. Billing validates the resulting value.
      subtotal =
        value.is_a?(String) ? Integer(value, 10, exception: false) : value
      issue =
        IssueInvoice.new(invoices: InvoiceRepository.new, customers: directory)
      invoice =
        issue.call(
          customer_id: attributes[:customer_id],
          subtotal_cents: subtotal,
        )
      render json: invoice.to_h, status: :created
    rescue InvalidInvoice => e
      render json: { errors: e.errors }, status: :unprocessable_content
    end

    def show
      @invoice = Invoice.new(**InvoiceRepository.new.fetch(params[:id]))
      @customer = directory.fetch(@invoice.customer_id)
      respond_to do |format|
        format.html
        format.json { render json: @invoice.to_h }
      end
    end

    private

    # Billing reaches Customers only through its public Directory.
    def directory
      Customers::Directory.new(customers: Customers::CustomerRepository.new)
    end
  end
end
