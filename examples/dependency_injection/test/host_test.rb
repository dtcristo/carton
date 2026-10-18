# frozen_string_literal: true

require_relative '../../../lib/carton'
Carton.setup_bundle
require 'minitest/autorun'
require 'logger'
require 'stringio'
require 'tmpdir'
require_relative '../adapters'

class HostTest < Minitest::Test
  Checkout = import_relative '../checkout'

  def test_host_adapters_keep_their_json_and_logging_dependencies_in_main
    Dir.mktmpdir('carton-checkout-test') do |dir|
      orders_path = File.join(dir, 'orders.json')
      payments_path = File.join(dir, 'payments.jsonl')
      order = { id: 42, items: [{ unit_price_cents: 1_500, quantity: 2 }] }
      File.write(orders_path, JSON.generate([order]))
      orders = Adapters::FileOrders.new(orders_path)
      output = StringIO.new
      checkout =
        Checkout::Service.new(
          orders:,
          payments: Adapters::DemoPayments.new(payments_path),
          logger: Logger.new(output),
        )

      result = checkout.call(order_id: 42)

      assert_equal(
        { order_id: 42, total_cents: 3_000, payment_id: 'demo-42' },
        result,
      )
      assert_equal order.merge(payment_id: 'demo-42'), orders.fetch(42)
      assert_equal(
        [{ id: 'demo-42', order_id: 42, amount_cents: 3_000 }],
        File
          .readlines(payments_path)
          .map { JSON.parse(it, symbolize_names: true) },
      )
      assert_includes output.string, 'Paid order 42: 3000 cents'
    end
  end
end
