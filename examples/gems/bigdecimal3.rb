# frozen_string_literal: true

# Bootstrap boxed RubyGems so this carton can activate exactly one gem version.
Carton.bootstrap_rubygems!

# Manual `gem` activation is the non-Bundler way to pick a version.
gem 'bigdecimal', '= 3.3.1'
require 'bigdecimal'

export version: BigDecimal::VERSION
