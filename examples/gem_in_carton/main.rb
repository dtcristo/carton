# frozen_string_literal: true

require_relative '../../lib/carton'

gem_in_carton = import_relative 'lib/gem_in_carton'

puts "gem_in_carton version = #{gem_in_carton.fetch(:version)}"
puts "gem_in_carton bigdecimal version = #{gem_in_carton.fetch(:bigdecimal_version)}"

STDOUT.flush
Process.exit!(0)
