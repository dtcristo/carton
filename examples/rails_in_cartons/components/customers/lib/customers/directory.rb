# frozen_string_literal: true

module Customers
  class Directory
    def initialize(customers:) = @customers = customers

    def register(name:)
      customer = Customer.new(name:)
      id = @customers.create(name: customer.name)
      Customer.new(id:, name: customer.name)
    end

    def fetch(id) = Customer.new(**@customers.fetch(id))
  end
end
