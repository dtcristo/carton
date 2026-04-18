# frozen_string_literal: true

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

BigDecimalBox = import 'bigdecimal'

export bigdecimal_version: BigDecimalBox.fetch(:BigDecimal)::VERSION
