# frozen_string_literal: true

module Customers
  class DirectoryController < Framework::BrowserController
    def index
      @customers = Customer.order(:id)
    end
  end
end
