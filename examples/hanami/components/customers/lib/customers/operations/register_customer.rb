# frozen_string_literal: true

module Customers
  module Operations
    class RegisterCustomer < Operation
      include Deps['contracts.customer', 'repos.customer_repo']

      def call(attributes)
        validation = customer.call(attributes)
        unless validation.success?
          step Failure[:invalid, validation.errors.to_h]
        end

        customer_repo.create(name: validation[:name].strip).to_h
      end
    end
  end
end
