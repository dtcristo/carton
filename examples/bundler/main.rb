# frozen_string_literal: true

require_relative '../../lib/carton'

# The app's own Gemfile is only here so Bundler can resolve the support gem.
Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

cartons_dir = File.expand_path('cartons', __dir__)

# Name-based imports stay explicit: main chooses which local carton entrypoints
# are available to `import 'name'`.
Dir
  .glob(File.join(cartons_dir, '*/lib'))
  .sort
  .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }

cartoned_gem = Gem.loaded_specs.fetch('cartoned_gem')

# Bundler found the support gem for us, so import its entry file directly from
# the resolved gem path.
cartoned_gem_entry =
  File.join(
    cartoned_gem.full_gem_path,
    cartoned_gem.require_paths.fetch(0),
    'cartoned_gem.rb',
  )
pp cartoned_gem_entry

MathHelper = import 'math_helper'
Billing = import 'billing'
# CartonedGemExports = import 'cartoned_gem'
CartonedGemExports = import cartoned_gem_entry

puts '-- Bundled require --'
puts "math_helper bigdecimal version = #{MathHelper.version}"
puts "math_helper number type = #{MathHelper.number_type}"
puts
puts '-- Transient bundled import --'
puts "billing summary = #{Billing.summary}"
puts "billing rounds with bigdecimal = #{Billing.rounding_version}"
puts
puts '-- Cartoned gem --'
puts "gem_in_carton version = #{CartonedGemExports.version}"
puts "invoice label = #{CartonedGemExports.invoice_label('42')}"
puts "INTERNAL_TEMPLATE defined? #{CartonedGemExports.const_defined?(:INTERNAL_TEMPLATE, false)}"

# Ruby 4.0.2 still crashes on normal exit after Bundler has been loaded in
# multiple boxes. Exit hard after printing so the example shows Carton's
# behavior without tripping that runtime bug.
STDOUT.flush
STDERR.flush
Process.exit!(0)
