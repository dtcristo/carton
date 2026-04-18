# frozen_string_literal: true

Carton.bootstrap_rubygems!

gem 'bigdecimal', '= 4.1.1'
require 'bigdecimal'

export version: BigDecimal::VERSION
