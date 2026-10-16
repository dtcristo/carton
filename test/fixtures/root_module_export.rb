# frozen_string_literal: true

# A gem-style Entrypoint: the root module is the Default Export, and Ruby's
# private_constant hides internals.
module Pricing
  class Calculator
    def total = Internal.round(1.005)
  end

  module Internal
    def self.round(value) = value.round(2)
  end
  private_constant :Internal
end

export default: Pricing
