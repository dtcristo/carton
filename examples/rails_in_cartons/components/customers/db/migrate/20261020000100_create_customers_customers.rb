# frozen_string_literal: true

class CreateCustomersCustomers < ActiveRecord::Migration[8.1]
  def change
    create_table :customers_customers do |t|
      t.string :name, null: false
      t.timestamps
    end
  end
end
