# frozen_string_literal: true

require 'carton'
require 'zeitwerk'

module Customers
end

# This domain's definitions and loader belong to its own Carton Box.
loader = Zeitwerk::Loader.for_gem
loader.setup
loader.eager_load

export Customers
