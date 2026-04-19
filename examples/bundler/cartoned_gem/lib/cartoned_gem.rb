# frozen_string_literal: true

require 'carton'

# This constant stays private because the file exports a smaller public surface.
INTERNAL_TEMPLATE = 'draft invoice'

module CartonedGem
  VERSION = '0.1.0'

  module_function

  def invoice_label(number)
    "INV-#{number.to_s.rjust(4, '0')}"
  end
end

export version: CartonedGem::VERSION,
       invoice_label: CartonedGem.method(:invoice_label)
