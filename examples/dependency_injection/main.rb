# frozen_string_literal: true

require_relative '../../lib/carton'

# Bundle boundary: only Main sets up this bundle. Checkout uses plain Ruby.
Carton.setup_bundle
require 'logger'
require 'tmpdir'
require_relative 'adapters'

# Carton boundary: only Checkout's export crosses into Main.
Checkout = import_relative 'checkout'

Dir.mktmpdir('carton-checkout') do |dir|
  orders_path = File.join(dir, 'orders.json')
  payments_path = File.join(dir, 'payments.jsonl')
  File.write(
    orders_path,
    JSON.generate(
      [{ id: 42, items: [{ unit_price_cents: 1_500, quantity: 2 }] }],
    ),
  )

  orders = Adapters::FileOrders.new(orders_path)
  logger =
    Logger.new($stdout, formatter: ->(_, _, _, message) { "#{message}\n" })

  # Ordinary constructor injection. The objects are shared, not copied into
  # the Carton; their methods retain Main's constants and loaded gems.
  checkout =
    Checkout::Service.new(
      orders:,
      payments: Adapters::DemoPayments.new(payments_path),
      logger:,
    )
  result = checkout.call(order_id: 42)

  puts "Checkout result: #{result.inspect}"
  puts "Stored payment: #{orders.fetch(42).fetch(:payment_id)}"
  puts "Recorded charge: #{File.read(payments_path).strip}"
end
