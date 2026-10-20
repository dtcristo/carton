# frozen_string_literal: true

module Billing
  class InvoiceRecord < ApplicationRecord
    belongs_to :customer,
               class_name: 'Customers::CustomerRecord',
               inverse_of: :invoices
  end
end
