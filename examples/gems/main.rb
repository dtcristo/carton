# frozen_string_literal: true

require_relative '../../lib/carton'

# Both cartons live next to main.rb, so import_relative is enough here.
bigdecimal3 = import_relative 'bigdecimal3'
bigdecimal4 = import_relative 'bigdecimal4'

puts '-- Manual RubyGems activation --'
puts "bigdecimal 3 carton = #{bigdecimal3.version}"
puts "bigdecimal 4 carton = #{bigdecimal4.version}"

# Ruby 4.0.2 still crashes on normal exit after loading two different boxed
# native-extension copies of bigdecimal. Exit hard after printing so the example
# stays focused on Carton's version isolation.
STDOUT.flush
STDERR.flush
Process.exit!(0)
