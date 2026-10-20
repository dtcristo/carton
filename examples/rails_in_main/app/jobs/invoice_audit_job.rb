# frozen_string_literal: true

class InvoiceAuditJob < ApplicationJob
  def perform(invoice)
    invoice.update!(audited_at: Time.current)
  end
end
