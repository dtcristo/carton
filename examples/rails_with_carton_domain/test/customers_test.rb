# frozen_string_literal: true

require_relative '../config/boot'
require 'carton'
require 'minitest/autorun'

class CustomersTest < Minitest::Test
  Customers = import 'customers'

  class MemoryCustomers
    attr_reader :records

    def initialize = @records = []

    def create(name:)
      id = @records.size + 1
      @records << { id:, name: }
      id
    end

    def fetch(id)
      @records.find { |record| record.fetch(:id) == id } ||
        raise(KeyError, id.to_s)
    end
  end

  def test_registering_and_fetching_a_customer_use_plain_values
    repository = MemoryCustomers.new
    directory = Customers::Directory.new(customers: repository)

    customer = directory.register(name: '  Ada  ')

    assert_equal({ id: 1, name: 'Ada' }, customer.to_h)
    assert_equal customer.to_h, directory.fetch(1).to_h
    assert customer.frozen?
  end

  def test_invalid_names_are_rejected_before_storage
    repository = MemoryCustomers.new
    directory = Customers::Directory.new(customers: repository)

    ['', '  ', nil, 1].each do |name|
      e =
        assert_raises(Customers::InvalidCustomer) { directory.register(name:) }
      assert_equal({ name: ['must not be blank'] }, e.errors)
    end
    assert_empty repository.records
  end
end
