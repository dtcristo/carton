# frozen_string_literal: true

# Inside the billing Carton, eager loaded by its Entrypoint.
module Billing
  class Invoice
    # The Box that ran this file.
    LOADED_IN = Ruby::Box.current

    def initialize(cents) = @cents = cents
    def to_s = format('invoice $%.2f', @cents / 100.0)
  end
end
