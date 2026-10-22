# frozen_string_literal: true

# An nsfile: with `loader.nsfile = 'ns.rb'`, this file inside carriers/
# defines Shipping::Carriers, the namespace itself, not Shipping::Carriers::Ns.
# It is left lazy, and the test references it first from the Main Box.
module Shipping
  module Carriers
    # The Box that ran this file.
    LOADED_IN = Ruby::Box.current
  end
end
