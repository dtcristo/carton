# frozen_string_literal: true

# A Carton of one file: math.rb, with no math/ directory beside it.
module MathTools
  VERSION = '1.0'

  def self.percent(amount, rate) = (amount * rate / 100.0).round(2)
end

export MathTools
