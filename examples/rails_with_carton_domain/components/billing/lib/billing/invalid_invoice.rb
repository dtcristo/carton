# frozen_string_literal: true

module Billing
  class InvalidInvoice < StandardError
    attr_reader :errors

    def initialize(errors)
      @errors = errors
      super(
        errors
          .map { |field, messages| "#{field} #{messages.join(', ')}" }
          .join('; '),
      )
    end
  end
end
