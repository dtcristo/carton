# frozen_string_literal: true

# Controllers stay in the Main Box with Rails and its autoloader; domain
# logic comes from the Carton.
class InvoicesController < ActionController::API
  def show
    invoice = Billing::Invoice.new(id: params[:id].to_i, subtotal_cents: 4_200)
    render json: invoice.to_h
  end
end
