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

  # Ruby 4.0.2 still crashes on normal exit after boxed native-extension loads,
  # so the runnable examples exit hard after printing or failing.
  STDOUT.flush
  STDERR.flush
  Process.exit!(status)
end

# Both cartons live next to main.rb, so import_relative is enough here.
bigdecimal3 = import_relative 'bigdecimal3'
bigdecimal4 = import_relative 'bigdecimal4'

puts '-- Manual RubyGems activation --'
puts "bigdecimal 3 carton = #{bigdecimal3.version}"
puts "bigdecimal 4 carton = #{bigdecimal4.version}"
