# frozen_string_literal: true

# Resolved by the app's lockfile, so every Carton sees the same version.
require 'bigdecimal'

module Pricing
  # Hidden from importers by Ruby's own visibility, which holds across Boxes.
  module Rounding
    def self.cents(amount) = amount.round(2)
  end
  private_constant :Rounding

  def self.total(prices)
    Rounding.cents(prices.sum { |price| BigDecimal(price) })
  end

  def self.bigdecimal_version = BigDecimal::VERSION
end

# The Carton's Public Surface is its root module.
export Pricing
