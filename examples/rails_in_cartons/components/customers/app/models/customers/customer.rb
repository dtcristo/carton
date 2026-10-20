# frozen_string_literal: true

module Customers
  class Customer < ApplicationRecord
    has_many :orders, class_name: 'Orders::Order', inverse_of: :customer
    validates :name, presence: true

    def display_name = name.to_s.strip.presence || 'Anonymous'
  end
end
