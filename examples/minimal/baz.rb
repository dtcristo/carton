# frozen_string_literal: true

module Baz
  def self.hello = 'Hello from Baz!'
end

# Baz exports its module the same way.
export :Baz
