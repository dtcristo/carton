# frozen_string_literal: true

module Foo
  def self.hello = 'Hello from Foo!'
end

# export_default returns the object itself from `import_relative 'foo'`.
export_default Foo
