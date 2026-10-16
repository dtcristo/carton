# frozen_string_literal: true

# Runs in the orders Box; `render`, `params`, and the rest are inherited from
# ActionController in the framework Box.
class OrdersController < ApplicationController
  def index
    render json: Order.includes(:customer).order(:id), include: :customer
  end

  def create
    customer = Customer.find(params.require(:customer_id))
    order = customer.orders.build(total_cents: params.require(:total_cents))

    if order.save
      render json: order, status: :created
    else
      render json: { errors: order.errors }, status: :unprocessable_content
    end
  end
end
