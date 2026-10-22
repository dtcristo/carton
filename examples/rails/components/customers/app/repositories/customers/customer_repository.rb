# frozen_string_literal: true

module Customers
  class CustomerRepository
    def create(name:) = CustomerRecord.create!(name: name).id

    def fetch(id)
      record = CustomerRecord.find(id)
      { id: record.id, name: record.display_name }
    end
  end
end
