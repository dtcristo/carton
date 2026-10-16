# frozen_string_literal: true

# A package with no dependencies of its own.
module Shipping
  RATE_PER_KG = 4

  def self.quote(kilograms) = kilograms * RATE_PER_KG
end

export_default Shipping
