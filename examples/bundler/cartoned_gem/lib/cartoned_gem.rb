# frozen_string_literal: true

require 'carton'

# This constant stays inside the Carton: only the exported module crosses.
INTERNAL_TEMPLATE = 'draft invoice'

module CartonedGem
  VERSION = '0.1.0'

  def self.invoice_label(number) = "INV-#{number.to_s.rjust(4, '0')}"
end

export CartonedGem
