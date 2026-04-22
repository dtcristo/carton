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

  # Ruby 4.0.2 can still crash on normal exit after boxed loads, so the runnable
  # examples exit hard after printing or failing.
  STDOUT.flush
  STDERR.flush
  Process.exit!(status)
end

# Single import — Foo exports one default value.
Foo = import_relative 'foo'

# Namespace import — Bar exports named methods and constants.
Bar = import_relative 'bar'

puts '-- Foo --'
puts Foo.hello

puts
puts '-- Bar (uses Baz internally) --'
puts Bar.hello
puts "Bar::MAGIC = #{Bar::MAGIC}"
