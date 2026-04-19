# frozen_string_literal: true

require_relative '../../lib/carton'

# Ruby 4.0.2 can still crash on normal exit after boxed loads. Exit hard after
# printing so the example stays focused on Carton's import/export behavior.
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
