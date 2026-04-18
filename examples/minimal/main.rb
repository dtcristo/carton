# frozen_string_literal: true

require_relative '../../lib/carton'

# Single import — Foo exports a module
Foo = import_relative 'foo'

# Namespace import — Bar exports a hash with methods and constants
Bar = import_relative 'bar'

puts '-- Foo --'
puts Foo.hello

puts
puts '-- Bar (uses Baz internally) --'
puts Bar.hello
puts "Bar::MAGIC = #{Bar::MAGIC}"

STDOUT.flush
Process.exit!(0)
