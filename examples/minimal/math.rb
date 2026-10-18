# frozen_string_literal: true

# A Carton of one file with no export, a Bare Carton: its top-level method
# and constant come back as a Carton::Namespace.
#: (Numeric amount, Numeric rate) -> Float
def percent(amount, rate) = (amount * rate / 100.0).round(2)

VERSION = '1.0'
