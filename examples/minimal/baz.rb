# frozen_string_literal: true

module Baz
  def self.hello = 'Hello from Baz!'
end

# Baz is another Default Export.
export_default Baz
