# frozen_string_literal: true

module Foo
  def self.hello = 'Hello from Foo!'
end

# The Default Export: `import_relative 'foo'` returns Foo itself.
export_default Foo
