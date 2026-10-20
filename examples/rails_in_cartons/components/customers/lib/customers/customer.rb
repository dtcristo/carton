# frozen_string_literal: true

module Customers
  class Customer
    attr_reader :id, :name

    def initialize(name:, id: nil)
      unless name.is_a?(String) && !name.strip.empty?
        raise InvalidCustomer.new(name: ['must not be blank'])
      end

      @id = id
      @name = name.strip.freeze
      freeze
    end

    def to_h = { id:, name: }
  end
end
