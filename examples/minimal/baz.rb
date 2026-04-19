# frozen_string_literal: true

module Baz
  def self.hello = 'Hello from Baz!'
end

# Baz is another single default export.
export_default Baz
