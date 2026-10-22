# frozen_string_literal: true

# Carton boundary: math is another Carton, and billing sees only its Export.
MathTools = import_relative '../math'

module Billing
  module Tax
    RATE = 10

    def self.on(amount) = MathTools.percent(amount, RATE)
  end
end
