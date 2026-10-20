# frozen_string_literal: true

class CustomersController < ApplicationController
  def create
    name = params.expect(customer: [:name])[:name]
    directory =
      Shop::Customers::Directory.new(customers: CustomerRepository.new)
    render json: directory.register(name:).to_h, status: :created
  rescue Shop::Customers::InvalidCustomer => e
    render json: { errors: e.errors }, status: :unprocessable_content
  end
end
