# frozen_string_literal: true

module Customers
  module Repos
    class CustomerRepo < DB::Repo[:customers]
      commands :create

      def get(id)
        customers.by_pk(id).one&.to_h
      end
    end
  end
end
