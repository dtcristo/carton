# frozen_string_literal: true

module Orders
  class OrdersController < ApplicationController
    def index
      render json: Order.includes(:customer).order(:id), include: :customer
    end

    def create
      customer = Customers::Customer.find(params.require(:customer_id))
      order =
        Order.new(customer: customer, total_cents: params.require(:total_cents))
      if order.save
        render json: order, status: :created
      else
        render json: { errors: order.errors }, status: :unprocessable_content
      end
    end
  end
end
