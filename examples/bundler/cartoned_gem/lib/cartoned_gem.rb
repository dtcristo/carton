# frozen_string_literal: true

require 'carton'

# This constant stays private because the file exports a smaller public surface.
INTERNAL_TEMPLATE = 'draft invoice'

module CartonedGem
  VERSION = '0.1.0'
end

def invoice_label(number)
  "INV-#{number.to_s.rjust(4, '0')}"
end

# `:invoice_label` exports the top-level method; `version:` is a plain value.
export :invoice_label, version: CartonedGem::VERSION
