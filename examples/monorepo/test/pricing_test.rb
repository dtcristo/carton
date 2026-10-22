# frozen_string_literal: true

# Unit test: pricing's files are ordinary Ruby, so this test loads them with
# a plain `require`. No Carton boundary and no Box, so it runs with or without
# RUBY_BOX=1 and can reach code that importers never see.

# Carton defines `export`, which is inert outside an import, so
# pricing.rb loads like any other file. The monorepo bundle puts pricing's
# lib/ on $LOAD_PATH and locks minitest.
require_relative '../../../lib/carton'
Carton.setup_bundle

require 'minitest/autorun'

# `require`, not `import`: Pricing loads straight into the test process, as
# it would in a gem's own test suite.
require 'pricing'

class PricingTest < Minitest::Test
  # `private_constant` makes `Pricing::Rounding` raise NameError, but
  # `const_get` still returns the constant. Naming it once here keeps this
  # test's one reach into pricing's internals easy to find.
  Rounding = Pricing.const_get(:Rounding)

  def test_cents_rounds_half_up
    assert_equal Rational('1.01'), Rounding.cents(Rational('1.005'))
  end
end
