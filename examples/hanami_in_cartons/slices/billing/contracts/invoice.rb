# frozen_string_literal: true

module Billing
  module Contracts
    class Invoice < Dry::Validation::Contract
      params do
        required(:customer_id).filled(Types::IntegerParam, gt?: 0)
        required(:subtotal_cents).filled(Types::IntegerParam, gteq?: 0)
      end
    end
  end
end
