# frozen_string_literal: true

# The pricing Entrypoint loads its own Interior in the same Carton Box.
require_relative 'pricing/tax'

module Pricing
  private_constant :Tax

  def self.total(subtotal) = subtotal + Tax.on(subtotal)
end

export Pricing
