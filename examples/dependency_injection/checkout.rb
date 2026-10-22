# frozen_string_literal: true

# These files are inside one Carton; requiring them crosses no boundary.
require_relative 'checkout/service'

# Export: the host receives this module, not the Carton's Box.
export Checkout
