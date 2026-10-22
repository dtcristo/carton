# frozen_string_literal: true

module Customers
  class Directory
    include Dry::Monads[:result]
    include Deps['repos.customer_repo']

    def find(id)
      customer = customer_repo.get(id)
      customer ? Success(customer) : Failure(:not_found)
    end
  end
end
