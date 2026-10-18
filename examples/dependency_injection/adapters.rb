# frozen_string_literal: true

# Host code, loaded with require in Main. JSON and file handling stay here.
require 'json'

module Adapters
  class FileOrders
    def initialize(path)
      @path = path
    end

    def fetch(id)
      read.find { |order| order.fetch(:id) == id } ||
        raise(KeyError, "Order #{id} not found")
    end

    def save(order)
      orders =
        read.map do |stored|
          stored.fetch(:id) == order.fetch(:id) ? order : stored
        end
      File.write(@path, JSON.generate(orders))
    end

    private

    def read = JSON.parse(File.read(@path), symbolize_names: true)
  end

  # Simulates a payment provider by recording charges locally. No real money
  # moves, and no network or credentials are needed.
  class DemoPayments
    def initialize(path)
      @path = path
    end

    def charge(order_id:, amount_cents:)
      id = "demo-#{order_id}"
      File.open(@path, 'a') do |file|
        file.puts(JSON.generate(id:, order_id:, amount_cents:))
      end
      id
    end
  end
end
