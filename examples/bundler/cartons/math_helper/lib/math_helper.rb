# frozen_string_literal: true

# Each Carton sets up its own Gemfile; activation stays inside this Box.
Carton.setup_bundle

# `require` makes BigDecimal available directly inside this Carton, but not in
# the importer.
require 'bigdecimal'

export version: BigDecimal::VERSION, number_type: BigDecimal.name
