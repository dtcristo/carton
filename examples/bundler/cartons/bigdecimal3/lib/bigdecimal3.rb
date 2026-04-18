# frozen_string_literal: true

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

BigDecimalBox = import 'bigdecimal'
BigDecimal2 = import_relative '../../bigdecimal2/lib/bigdecimal2'

export(
  bigdecimal_version: BigDecimalBox.fetch(:BigDecimal)::VERSION,
  transient_version: BigDecimal2.fetch(:bigdecimal_version),
)
