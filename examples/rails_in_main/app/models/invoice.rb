# frozen_string_literal: true

# Persistence belongs to Rails in Main. Only values go into the Billing Carton.
class Invoice < ApplicationRecord
  validates :subtotal_cents,
            numericality: {
              only_integer: true,
              greater_than_or_equal_to: 0,
            }

  def quote
    Shop::Billing::Invoice.new(id: id, subtotal_cents: subtotal_cents)
  end
end
