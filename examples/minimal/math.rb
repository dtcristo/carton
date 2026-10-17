# frozen_string_literal: true

# A Carton of one file, with Named Exports: a method and a constant.
#: (Numeric amount, Numeric rate) -> Float
export def percent(amount, rate) = (amount * rate / 100.0).round(2)

export VERSION: '1.0'
