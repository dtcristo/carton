# frozen_string_literal: true

module Orders
  class ReceiptJob < Framework::ApplicationJob
    def perform(order)
      order.update!(receipt_sent: true)
    end
  end
end
