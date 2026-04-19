# frozen_string_literal: true

# This carton has its own Gemfile, so it bootstraps boxed RubyGems before
# asking Bundler for the gems in that bundle.
Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

# `import 'bigdecimal'` treats the gem entry file like another carton. The gem's
# constants stay behind the returned namespace instead of becoming top-level here.
BigDecimalBox = import 'bigdecimal'

export version: BigDecimalBox::BigDecimal::VERSION
