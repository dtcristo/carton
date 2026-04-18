# frozen_string_literal: true

Carton.bootstrap_rubygems!

gem 'bigdecimal', '= 3.3.1'
require 'bigdecimal'

export version: BigDecimal::VERSION
