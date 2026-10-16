# frozen_string_literal: true

module Foo
  def self.hello = 'Hello from Foo!'
end

# `default:` is the Default Export: `import_relative 'foo'` returns Foo itself.
export default: Foo
