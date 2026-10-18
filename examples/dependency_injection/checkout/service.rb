# frozen_string_literal: true

module Checkout
  class Service
    def initialize(orders:, payments:, logger:)
      @orders = orders
      @payments = payments
      @logger = logger
    end

    def call(order_id:)
      order = @orders.fetch(order_id)
      total_cents =
        order
          .fetch(:items)
          .sum { |item| item.fetch(:unit_price_cents) * item.fetch(:quantity) }

      # Injected methods run where they were defined, in the host's Main Box.
      payment_id = @payments.charge(order_id:, amount_cents: total_cents)
      @orders.save(order.merge(payment_id:))
      @logger.info("Paid order #{order_id}: #{total_cents} cents")

      # Plain values cross back; no repository or payment-provider types leak.
      { order_id:, total_cents:, payment_id: }
    end
  end
end
