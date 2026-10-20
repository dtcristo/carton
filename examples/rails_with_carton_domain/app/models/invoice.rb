# frozen_string_literal: true

# A storage record in Main. Billing owns validation and invoice pricing.
class Invoice < ApplicationRecord
  belongs_to :customer, inverse_of: :invoices
end
