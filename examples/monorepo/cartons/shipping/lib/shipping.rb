# frozen_string_literal: true

require 'carton'

# A Carton whose only runtime gem is carton.
module Shipping
  RATE_PER_KG = 4

  def self.quote(kilograms) = kilograms * RATE_PER_KG
end

export Shipping
