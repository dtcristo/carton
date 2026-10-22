# frozen_string_literal: true

class CreateBillingInvoiceRecords < ActiveRecord::Migration[8.1]
  def change
    create_table :billing_invoice_records do |table|
      table.references :customer,
                       null: false,
                       foreign_key: {
                         to_table: :customers_customers,
                       }
      table.integer :subtotal_cents, null: false
      table.integer :tax_cents, null: false
      table.timestamps
    end
  end
end
