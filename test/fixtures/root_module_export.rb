# frozen_string_literal: true

# A gem-style Entrypoint: export the root module, hide internals with Ruby's
# private_constant.
module Pricing
  class Calculator
    def total = Internal.round(1.005)
  end

  module Internal
    def self.round(value) = value.round(2)
  end
  private_constant :Internal
end

export :Pricing
