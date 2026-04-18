# frozen_string_literal: true

require_relative '../../lib/carton'

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

cartons_dir = File.expand_path('cartons', __dir__)

# Name-based imports stay explicit: the caller chooses which carton lib
# directories are available here.
Dir
  .glob(File.join(cartons_dir, '*/lib'))
  .sort
  .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }
gem_in_carton_lib =
  File.join(Gem.loaded_specs.fetch('gem_in_carton').full_gem_path, 'lib')
unless $LOAD_PATH.include?(gem_in_carton_lib)
  $LOAD_PATH.unshift(gem_in_carton_lib)
end

BigDecimal4 = import 'bigdecimal4'
import('bigdecimal3') => { bigdecimal_version:, transient_version: }
GemInCarton = import 'gem_in_carton'

puts '-- Bundled require --'
puts "bigdecimal4 version = #{BigDecimal4.version}"
puts
puts '-- Bundled import --'
puts "bigdecimal3 version = #{bigdecimal_version}"
puts "bigdecimal2 version = #{transient_version}"
puts
puts '-- Gem carton --'
puts "gem_in_carton version = #{GemInCarton.fetch(:version)}"
puts "gem_in_carton bigdecimal version = #{GemInCarton.fetch(:bigdecimal_version)}"

STDOUT.flush
Process.exit!(0)
