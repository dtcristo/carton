# frozen_string_literal: true

class StoreInvoiceTax < ActiveRecord::Migration[8.1]
  def up
    add_column :invoices, :tax_cents, :integer, null: false, default: 0
    # Preserve the earlier example's ten-percent rule for existing records.
    execute 'UPDATE invoices SET tax_cents = (subtotal_cents + 5) / 10'
    change_column_default :invoices, :tax_cents, from: 0, to: nil
    remove_column :invoices, :audited_at
  end

  def down
    add_column :invoices, :audited_at, :datetime
    remove_column :invoices, :tax_cents
  end
end
