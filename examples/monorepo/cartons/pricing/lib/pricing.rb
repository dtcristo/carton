# frozen_string_literal: true

require 'carton'

module Pricing
  # Hidden from Importers by Ruby's own visibility, which holds across Boxes.
  module Rounding
    def self.cents(amount) = amount.round(2)
  end
  private_constant :Rounding

  # Prices are Strings, summed exactly as Rationals.
  def self.total(prices)
    Rounding.cents(prices.sum { |price| Rational(price) })
  end
end

# Export: the Carton's root module.
export Pricing
