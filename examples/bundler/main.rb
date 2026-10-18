# frozen_string_literal: true

require_relative '../../lib/carton'

# The top-level app uses Bundler's normal setup. Cartons with their own Gemfile
# call `Carton.setup_bundle` inside their own entrypoints.
Carton.setup_bundle

# Each local Carton is a gem-shaped directory (cartons/billing/lib/billing.rb),
# so it imports by its directory. The path gem imports by name.
MathHelper = import_relative 'cartons/math_helper'
Billing = import_relative 'cartons/billing'
CartonedGem = import 'cartoned_gem'

puts '-- Bundled require --'
puts "math_helper bigdecimal version = #{MathHelper[:version]}"
puts "math_helper number type = #{MathHelper[:number_type]}"
puts
puts '-- Transient bundled import --'
puts "billing summary = #{Billing[:summary]}"
puts "billing rounds with bigdecimal = #{Billing[:rounding_version]}"
puts
puts '-- Cartoned gem --'
puts "cartoned_gem version = #{CartonedGem::VERSION}"
puts "invoice label = #{CartonedGem.invoice_label('42')}"
