# frozen_string_literal: true

require_relative '../../lib/carton'

bigdecimal4 = import_relative 'bigdecimal4'
bigdecimal3 = import_relative 'bigdecimal3'

puts '-- Manual RubyGems activation --'
puts "bigdecimal 4 carton = #{bigdecimal4.fetch(:version)}"
puts "bigdecimal 3 carton = #{bigdecimal3.fetch(:version)}"

STDOUT.flush
Process.exit!(0)
