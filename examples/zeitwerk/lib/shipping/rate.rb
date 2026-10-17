# frozen_string_literal: true

# Inside the shipping Carton, autoloaded and reloaded by its loader.
module Shipping
  class Rate
    # The Box that ran this file.
    LOADED_IN = Ruby::Box.current

    def self.quote(kilograms) = 500 + (200 * kilograms)
  end
end
