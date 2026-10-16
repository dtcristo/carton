# frozen_string_literal: true

# Cartons can import other cartons internally just like the main file can.
Baz = import_relative('baz')::Baz

def hello
  "Hello from Bar! (#{Baz.hello})"
end

# Named exports return a Carton::Exports namespace: `:hello` exports the
# top-level method, and `MAGIC:` exports a plain value as a constant.
export :hello, MAGIC: 42
