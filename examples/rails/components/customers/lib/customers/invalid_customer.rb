# frozen_string_literal: true

module Customers
  class InvalidCustomer < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super('name must not be blank')
    end
  end
end
