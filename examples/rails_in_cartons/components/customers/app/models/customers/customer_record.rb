# frozen_string_literal: true

module Customers
  class CustomerRecord < ApplicationRecord
    self.table_name = 'customers_customers'
    has_many :invoices,
             class_name: 'Billing::InvoiceRecord',
             inverse_of: :customer

    def display_name = name.to_s.strip
  end
end
