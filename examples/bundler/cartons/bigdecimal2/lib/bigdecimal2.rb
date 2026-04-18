# frozen_string_literal: true

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

require 'bigdecimal'

export bigdecimal_version: BigDecimal::VERSION
