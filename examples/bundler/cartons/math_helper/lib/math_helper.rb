# frozen_string_literal: true

# Each bundled carton bootstraps boxed RubyGems before it asks Bundler to set up
# that carton's own Gemfile.
Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

# `require` makes BigDecimal available directly inside this carton, but not in
# the caller that imported the carton.
require 'bigdecimal'

export version: BigDecimal::VERSION, number_type: BigDecimal.name
