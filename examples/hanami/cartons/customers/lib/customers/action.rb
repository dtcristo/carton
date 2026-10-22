# frozen_string_literal: true

module Customers
  class Action < Hanami::Action
    include Dry::Monads[:result]
  end
end
