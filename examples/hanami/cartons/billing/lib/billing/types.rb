# frozen_string_literal: true

module Billing
  module Types
    include Dry.Types()

    # Form fields arrive as strings. JSON fractions and booleans must stay invalid.
    IntegerParam =
      Strict::Integer.constructor do |value|
        if value.is_a?(::String) && value.match?(/\A[+-]?\d+\z/)
          value.to_i
        else
          value
        end
      end
  end
end
