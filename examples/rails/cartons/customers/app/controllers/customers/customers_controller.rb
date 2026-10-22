# frozen_string_literal: true

module Customers
  class CustomersController < ApplicationController
    def create
      customer =
        Directory.new(customers: CustomerRepository.new).register(
          name: params.expect(customer: [:name])[:name],
        )
      render json: customer.to_h, status: :created
    rescue InvalidCustomer => e
      render json: { errors: e.errors }, status: :unprocessable_content
    end
  end
end
