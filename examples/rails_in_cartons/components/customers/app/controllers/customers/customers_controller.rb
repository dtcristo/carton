# frozen_string_literal: true

module Customers
  class CustomersController < ApplicationController
    def index = render(json: Customer.order(:id))

    def create
      customer = Customer.new(params.permit(:name))
      if customer.save
        render json: customer, status: :created
      else
        render json: { errors: customer.errors }, status: :unprocessable_content
      end
    end
  end
end
