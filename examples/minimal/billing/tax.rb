# frozen_string_literal: true

# Another Carton, imported across a boundary: billing sees only its exports.
MathTools = import_relative '../math'

module Billing
  module Tax
    RATE = 10

    def self.on(amount) = MathTools.percent(amount, RATE)
  end
end
