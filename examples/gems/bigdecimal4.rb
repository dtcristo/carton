# frozen_string_literal: true

# Manual `gem` activation is the non-Bundler way to pick a version. Each Box
# has its own RubyGems activation state, so this choice stays in this carton.
gem 'bigdecimal', '= 4.1.1'
require 'bigdecimal'

export version: BigDecimal::VERSION
