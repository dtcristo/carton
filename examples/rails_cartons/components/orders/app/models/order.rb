# frozen_string_literal: true

class Order < ApplicationRecord
  belongs_to :customer
  validates :total_cents, numericality: { greater_than: 0 }
end
