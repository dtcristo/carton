# frozen_string_literal: true

class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.integer :subtotal_cents, null: false
      t.datetime :audited_at
      t.timestamps
    end
  end
end
