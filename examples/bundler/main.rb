# frozen_string_literal: true

require_relative '../../lib/carton'

# Ruby 4.0.2 still crashes on normal exit after Bundler has been loaded in
# multiple boxes. Exit hard after printing so the example shows Carton's
# behavior without tripping that runtime bug.
at_exit do
  status =
    if $!.is_a?(SystemExit)
      $!.status
    elsif $!
      1
    else
      0
    end

  STDOUT.flush
  STDERR.flush
  Process.exit!(status)
end

# The app's own Gemfile is only here so Bundler can resolve the support gem.
Carton.with_bundle { require 'bundler/setup' }

cartons_dir = File.expand_path('cartons', __dir__)

# Name-based imports stay explicit: main chooses which local carton entrypoints
# are available to `import 'name'`.
Dir
  .glob(File.join(cartons_dir, '*/lib'))
  .sort
  .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }

math_gem = Gem.loaded_specs.fetch('gem_in_carton')

# Bundler found the support gem for us, so import its entry file directly from
# the resolved gem path.
gem_in_carton_entry =
  File.join(
    math_gem.full_gem_path,
    math_gem.require_paths.fetch(0),
    'gem_in_carton.rb',
  )

MathHelper = import 'math_helper'
Billing = import 'billing'
GemInCarton = import gem_in_carton_entry

main_can_see_bigdecimal =
  begin
    BigDecimal
    true
  rescue NameError
    false
  end

puts '-- Bundled require --'
puts "math_helper bigdecimal version = #{MathHelper.fetch(:version)}"
puts "math_helper number type = #{MathHelper.fetch(:number_type)}"
puts "main can see BigDecimal? #{main_can_see_bigdecimal}"
puts
puts '-- Transient bundled import --'
puts "billing summary = #{Billing.fetch(:summary)}"
puts "billing rounds with bigdecimal = #{Billing.fetch(:rounding_version)}"
puts
puts '-- Gem carton --'
puts "gem_in_carton version = #{GemInCarton.fetch(:version)}"
puts "invoice label = #{GemInCarton.fetch(:invoice_label).('42')}"
puts "exports hide INTERNAL_TEMPLATE? #{GemInCarton.const_defined?(:INTERNAL_TEMPLATE, false)}"
