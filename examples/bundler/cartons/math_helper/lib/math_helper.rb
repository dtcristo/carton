# frozen_string_literal: true

# Each Carton sets up its own Gemfile; activation stays inside this Box.
Carton.with_bundle { require 'bundler/setup' }

# `require` makes BigDecimal available directly inside this carton, but not in
# the caller that imported the carton.
require 'bigdecimal'

export version: BigDecimal::VERSION, number_type: BigDecimal.name
