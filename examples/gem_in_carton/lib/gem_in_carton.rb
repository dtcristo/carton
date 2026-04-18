# frozen_string_literal: true

require 'carton'

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

require 'bigdecimal'

module GemInCarton
  VERSION = '0.1.0'
end

export version: GemInCarton::VERSION, bigdecimal_version: BigDecimal::VERSION
