# frozen_string_literal: true

class CreateOrdersOrders < ActiveRecord::Migration[8.1]
  def change
    create_table :orders_orders do |t|
      t.references :customer,
                   null: false,
                   foreign_key: {
                     to_table: :customers_customers,
                   }
      t.integer :total_cents, null: false
      t.boolean :receipt_sent, default: false, null: false
      t.timestamps
    end
  end
end
