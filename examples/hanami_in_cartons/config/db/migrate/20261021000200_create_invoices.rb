# frozen_string_literal: true

ROM::SQL.migration do
  change do
    create_table :invoices do
      primary_key :id
      foreign_key :customer_id, :customers, null: false
      Integer :subtotal_cents, null: false
      Integer :tax_cents, null: false
    end
  end
end
