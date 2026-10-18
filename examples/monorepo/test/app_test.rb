# frozen_string_literal: true

# Integration test: imports packages the way main.rb does, so each one loads
# in its own Box and the test sees only its Public Surface. Needs RUBY_BOX=1.

require_relative '../../../lib/carton'
Carton.setup_bundle

require 'minitest/autorun'

class AppTest < Minitest::Test
  # --- Carton boundary: only each package's export value crosses ---
  # Imports are cached per process, so every test shares these Cartons.
  Billing = import 'billing'
  Pricing = import 'pricing'

  def test_invoice_totals_line_items
    assert_equal 'Invoice 42: 25.0', Billing.invoice(42, %w[19.99 5.01])
  end

  def test_billing_and_the_app_share_one_pricing_carton
    assert_same Pricing, Billing::Pricing
  end

  def test_rounding_stays_private
    assert_raises(NameError) { Pricing::Rounding }
  end

  def test_bigdecimal_stays_in_the_pricing_box
    refute defined?(BigDecimal)
  end
end
