# frozen_string_literal: true

require_relative '../../lib/carton'

# Import the billing Carton: billing.rb plus everything in billing/.
Billing = import_relative 'billing'
puts "Invoice total: #{Billing.invoice(40).total}"

# billing imports math too, and both get the same MathTools module.
MathTools = import_relative 'math'
puts "10% of 40: #{MathTools.percent(40, 10)} (math #{MathTools::VERSION})"
