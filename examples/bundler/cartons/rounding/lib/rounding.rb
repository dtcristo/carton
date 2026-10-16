# frozen_string_literal: true

# This carton has its own Gemfile; activation stays inside this Box.
Carton.with_bundle { require 'bundler/setup' }

# `import 'bigdecimal'` treats the gem entry file like another carton. The gem's
# constants stay behind the returned namespace instead of becoming top-level here.
BigDecimalBox = import 'bigdecimal'

export version: BigDecimalBox::BigDecimal::VERSION
