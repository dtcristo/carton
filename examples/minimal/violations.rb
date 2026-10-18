# frozen_string_literal: true

# Deliberately invalid code for `carton check`; main.rb is the working app.
require_relative '../../lib/carton'

Billing = import_relative 'billing'

# Ruby's private_constant keeps Tax out of billing's Public Surface.
puts Billing::Tax

# Only the Entrypoint can be imported, never an Interior file.
import_relative 'billing/invoice'
