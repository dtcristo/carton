# frozen_string_literal: true

require_relative '../../lib/carton'

at_exit do
  status =
    if $!.is_a?(SystemExit)
      $!.status
    elsif $!
      1
    else
      0
    end

  # Ruby 4.0.2 still crashes on normal exit after boxed Bundler loads, so the
  # runnable examples exit hard after printing or failing.
  STDOUT.flush
  STDERR.flush
  Process.exit!(status)
end

# The top-level app only needs Bundler's normal setup. Bundled cartons loaded in
# fresh boxes call `Carton.bootstrap_rubygems!` inside their own entrypoints.
Carton.with_bundle { require 'bundler/setup' }

cartons_dir = File.expand_path('cartons', __dir__)

# Name-based imports stay explicit: main chooses which local carton entrypoints
# are available to `import 'name'`.
Dir
  .glob(File.join(cartons_dir, '*/lib'))
  .sort
  .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }

MathHelper = import 'math_helper'
Billing = import 'billing'
# Bundler put the support gem on this box's load path, so it imports by name
# just like any other carton feature.
CartonedGemExports = import 'cartoned_gem'

puts '-- Bundled require --'
puts "math_helper bigdecimal version = #{MathHelper.version}"
puts "math_helper number type = #{MathHelper.number_type}"
puts
puts '-- Transient bundled import --'
puts "billing summary = #{Billing.summary}"
puts "billing rounds with bigdecimal = #{Billing.rounding_version}"
puts
puts '-- Cartoned gem --'
puts "cartoned_gem version = #{CartonedGemExports.version}"
puts "invoice label = #{CartonedGemExports.invoice_label('42')}"
puts "INTERNAL_TEMPLATE defined? #{CartonedGemExports.const_defined?(:INTERNAL_TEMPLATE, false)}"
