# frozen_string_literal: true

# This helper belongs to the pricing Carton's Interior, not its Public Surface.
module Pricing
  module Tax
    def self.on(subtotal) = subtotal * 0.1
  end
end
