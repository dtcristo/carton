# frozen_string_literal: true

class CustomerRepository
  def create(name:) = Customer.create!(name:).id

  def fetch(id)
    customer = Customer.find(id)
    { id: customer.id, name: customer.name }
  end
end
