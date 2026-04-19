# frozen_string_literal: true

require_relative '../../lib/carton'

# Ruby 4.0.2 still crashes on normal exit after loading two different boxed
# native-extension copies of bigdecimal. Exit hard after printing so the example
# stays focused on Carton's version isolation.
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

# Both cartons live next to main.rb, so import_relative is enough here.
bigdecimal4 = import_relative 'bigdecimal4'
bigdecimal3 = import_relative 'bigdecimal3'

puts '-- Manual RubyGems activation --'
puts "bigdecimal 4 carton = #{bigdecimal4.fetch(:version)}"
puts "bigdecimal 3 carton = #{bigdecimal3.fetch(:version)}"
