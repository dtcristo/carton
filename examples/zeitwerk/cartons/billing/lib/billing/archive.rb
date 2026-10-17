# frozen_string_literal: true

# Inside the billing Carton, but excluded from eager loading, so it loads on
# first reference. main.rb references it first, so this file runs in the Main
# Box, not the billing Carton's Box.
module Billing
  module Archive
    # The Box that ran this file.
    LOADED_IN = Ruby::Box.current
  end
end
