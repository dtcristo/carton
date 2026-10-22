# frozen_string_literal: true

# Deliberately invalid code for `carton check`; main.rb is the working app.
require_relative '../../lib/carton'

Pricing = import_relative 'pricing'

# Ruby's private_constant keeps Tax out of Pricing's Public Surface.
puts Pricing::Tax

# Only the Entrypoint can be imported, never an Interior file.
import_relative 'pricing/tax'
