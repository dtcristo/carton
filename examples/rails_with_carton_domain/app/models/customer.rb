# frozen_string_literal: true

# Storage in Main; the Customers Carton owns name validation.
class Customer < ApplicationRecord
  has_many :invoices, inverse_of: :customer
end
