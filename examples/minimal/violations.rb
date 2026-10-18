# frozen_string_literal: true

# Deliberately invalid code for `carton check`; main.rb is the working app.
require_relative '../../lib/carton'

Billing = import_relative 'billing'

# Ruby's private_constant keeps this internal module out of the public API.
puts Billing::Tax

# Only the Entrypoint can be imported, never a file inside its directory.
import_relative 'billing/invoice'
