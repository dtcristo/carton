# frozen_string_literal: true

# Cartons can import other cartons internally just like the main file can.
Baz = import_relative 'baz'

def hello
  "Hello from Bar! (#{Baz.hello})"
end

# Named exports return a Carton::Exports namespace.
export hello: method(:hello), MAGIC: 42
