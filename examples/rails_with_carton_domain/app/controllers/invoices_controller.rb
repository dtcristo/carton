# frozen_string_literal: true

class InvoicesController < ApplicationController
  def show
    @invoice = Invoice.find(params[:id])
    @quote = @invoice.quote
    respond_to do |format|
      format.html
      format.json { render json: @quote.to_h }
    end
  end

  def create
    invoice = Invoice.new(params.expect(invoice: [:subtotal_cents]))
    if invoice.save
      render json: invoice.quote.to_h, status: :created
    else
      render json: { errors: invoice.errors }, status: :unprocessable_content
    end
  end
end
