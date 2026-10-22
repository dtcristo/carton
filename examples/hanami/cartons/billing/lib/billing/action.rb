# frozen_string_literal: true

module Billing
  class Action < Hanami::Action
    include Dry::Monads[:result]
  end
end
