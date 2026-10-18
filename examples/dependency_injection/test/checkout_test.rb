# frozen_string_literal: true

require_relative '../../../lib/carton'
Carton.setup_bundle
require 'minitest/autorun'

class CheckoutTest < Minitest::Test
  # Import the real Carton, as the host does. Only the adapters are fakes.
  Checkout = import_relative '../checkout'
  class PaymentDeclined < StandardError
  end

  def setup
    @order = {
      id: 42,
      items: [
        { unit_price_cents: 1_500, quantity: 2 },
        { unit_price_cents: 250, quantity: 1 },
      ],
    }
    @orders = Minitest::Mock.new
    @payments = Minitest::Mock.new
    @logger = Minitest::Mock.new
    @checkout =
      Checkout::Service.new(
        orders: @orders,
        payments: @payments,
        logger: @logger,
      )
  end

  def test_charges_total_saves_payment_and_logs_success
    @orders.expect(:fetch, @order, [42])
    @payments.expect(:charge, 'payment-123', order_id: 42, amount_cents: 3_250)
    @orders.expect(:save, nil, [@order.merge(payment_id: 'payment-123')])
    @logger.expect(:info, nil, ['Paid order 42: 3250 cents'])

    assert_equal(
      { order_id: 42, total_cents: 3_250, payment_id: 'payment-123' },
      @checkout.call(order_id: 42),
    )
    [@orders, @payments, @logger].each(&:verify)
    refute @order.key?(:payment_id)
  end

  def test_declined_payment_does_not_save_or_log_success
    @orders.expect(:fetch, @order, [42])
    # This adapter is defined in Main, including the error it raises.
    payments = Object.new
    def payments.charge(order_id:, amount_cents:)
      raise PaymentDeclined,
            "Declined order #{order_id} for #{amount_cents} cents"
    end
    checkout =
      Checkout::Service.new(orders: @orders, payments:, logger: @logger)

    assert_raises(PaymentDeclined) { checkout.call(order_id: 42) }
    @orders.verify
    # No save or logger expectations: either call would fail this test.
  end

  def test_unknown_order_does_not_charge
    orders = {} # Hash#fetch supplies the repository's missing-order behavior.
    checkout =
      Checkout::Service.new(orders:, payments: @payments, logger: @logger)

    assert_raises(KeyError) { checkout.call(order_id: 404) }
  end
end
