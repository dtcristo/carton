# frozen_string_literal: true

class CustomersController < ApplicationController
  def index = render(json: Customer.order(:id))

  def create
    customer = Customer.create!(name: params.require(:name))
    render json: customer, status: :created
  end
end
