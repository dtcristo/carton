# frozen_string_literal: true

require_relative '../../lib/carton'

# Foo exports its module as a constant; take it from the namespace.
Foo = import_relative('foo')::Foo

# Namespace import — Bar exports named methods and constants.
Bar = import_relative 'bar'

puts '-- Foo --'
puts Foo.hello

puts
puts '-- Bar (uses Baz internally) --'
puts Bar.hello
puts "Bar::MAGIC = #{Bar::MAGIC}"
