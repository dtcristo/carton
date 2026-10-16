# frozen_string_literal: true

module Foo
  def self.hello = 'Hello from Foo!'
end

# A capitalized Symbol exports a constant; importers read it as `foo::Foo`.
export :Foo
