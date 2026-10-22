# frozen_string_literal: true

require_relative '../../lib/carton'

# Carton boundary: the app uses only Pricing's exported method. Its RBS
# declares the return type.
Pricing = import_relative 'pricing'
puts "Price with tax: #{Pricing.total(40)}"
