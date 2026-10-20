# frozen_string_literal: true

class InvoicesController < ApplicationController
  def show
    @invoice =
      Shop::Billing::Invoice.new(**InvoiceRepository.new.fetch(params[:id]))
    @customer =
      Shop::Customers::Directory.new(customers: CustomerRepository.new).fetch(
        @invoice.customer_id,
      )
    respond_to do |format|
      format.html
      format.json { render json: @invoice.to_h }
    end
  end

  def create
    attributes = params.expect(invoice: %i[customer_id subtotal_cents])
    value = attributes[:subtotal_cents]
    # Form parameters are strings. Coercion belongs to the HTTP adapter;
    # Billing decides whether the resulting value is a valid subtotal.
    subtotal =
      value.is_a?(String) ? Integer(value, 10, exception: false) : value
    issue =
      Shop::Billing::IssueInvoice.new(
        invoices: InvoiceRepository.new,
        customers: CustomerRepository.new,
      )
    invoice =
      issue.call(
        customer_id: attributes[:customer_id],
        subtotal_cents: subtotal,
      )
    render json: invoice.to_h, status: :created
  rescue Shop::Billing::InvalidInvoice => e
    render json: { errors: e.errors }, status: :unprocessable_content
  end
end
