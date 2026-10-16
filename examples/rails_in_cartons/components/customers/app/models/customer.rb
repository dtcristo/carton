# frozen_string_literal: true

class Customer < ApplicationRecord
  has_many :orders
  validates :name, presence: true
end
