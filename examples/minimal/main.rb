# frozen_string_literal: true

require_relative '../../lib/carton'

# Default import: Foo exports its module with `export_default`.
Foo = import_relative 'foo'

# Namespace import — Bar exports named methods and constants.
Bar = import_relative 'bar'

puts '-- Foo --'
puts Foo.hello

puts
puts '-- Bar (uses Baz internally) --'
puts Bar.hello
puts "Bar::MAGIC = #{Bar::MAGIC}"
