# frozen_string_literal: true

class CreateCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers do |t|
      t.string :name, null: false
      t.timestamps
    end
    add_reference :invoices, :customer, null: false, foreign_key: true
  end
end
