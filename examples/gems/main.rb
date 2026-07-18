# frozen_string_literal: true

require_relative '../../lib/carton'

# Both cartons live next to main.rb, so import_relative is enough here.
bigdecimal3 = import_relative 'bigdecimal3'
bigdecimal4 = import_relative 'bigdecimal4'

puts '-- Manual RubyGems activation --'
puts "bigdecimal 3 carton = #{bigdecimal3.version}"
puts "bigdecimal 4 carton = #{bigdecimal4.version}"
