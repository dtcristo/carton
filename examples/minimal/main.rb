# frozen_string_literal: true

require_relative '../../lib/carton'

# Carton boundary: billing.rb plus everything in billing/ load in their own
# Box, and only billing's Export comes back.
Billing = import_relative 'billing'
puts "Invoice total: #{Billing.invoice(40).total}"

# Carton boundary: billing imports math too, so this Shared Import returns the
# same MathTools module.
MathTools = import_relative 'math'
puts "10% of 40: #{MathTools.percent(40, 10)} (math #{MathTools::VERSION})"
