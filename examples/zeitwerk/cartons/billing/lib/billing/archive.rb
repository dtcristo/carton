# frozen_string_literal: true

# Inside the billing Carton, but excluded from eager loading, so it loads on
# first reference. main.rb references it first, and this file still runs in
# the billing Carton's Box.
module Billing
  module Archive
    # The Box that ran this file.
    LOADED_IN = Ruby::Box.current
  end
end
