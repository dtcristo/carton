# frozen_string_literal: true

# Inside the shipping Carton, in the namespace carriers/ns.rb defines.
module Shipping
  module Carriers
    class Post
      # The Box that ran this file.
      LOADED_IN = Ruby::Box.current
    end
  end
end
