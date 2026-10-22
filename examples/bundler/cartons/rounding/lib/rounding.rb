# frozen_string_literal: true

# This Carton Bundle uses its own Gemfile; activation stays in the Carton Box.
Carton.setup_bundle

# Legacy gems load inside this Carton with require. Only the explicit Export
# crosses into the Importer; BigDecimal itself stays in this Carton Box.
require 'bigdecimal'

export version: BigDecimal::VERSION
