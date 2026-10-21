# frozen_string_literal: true

module Customers
  module Contracts
    class Customer < Dry::Validation::Contract
      params { required(:name).filled(:string) }

      rule(:name) { key.failure('must not be blank') if value.strip.empty? }
    end
  end
end
