# frozen_string_literal: true

module Orders
  class Order < ApplicationRecord
    belongs_to :customer, class_name: 'Customers::Customer', inverse_of: :orders
    validates :total_cents, numericality: { greater_than: 0 }
  end
end
