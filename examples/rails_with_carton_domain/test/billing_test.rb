# frozen_string_literal: true

# Only Bundler and Carton boot here. Run this file directly without Rails.
require_relative '../config/boot'
require 'carton'
require 'minitest/autorun'

class BillingTest < Minitest::Test
  Billing = import 'billing'

  class MemoryCustomers
    def fetch(id)
      { 1 => { id: 1, name: 'Ada' } }.fetch(id)
    end
  end

  class MemoryInvoices
    attr_reader :records

    def initialize = @records = []

    def create(**attributes)
      id = @records.size + 1
      @records << attributes.merge(id:)
      id
    end
  end

  def test_issuing_an_invoice_validates_prices_and_persists_it
    invoices = MemoryInvoices.new
    issue = Billing::IssueInvoice.new(customers: MemoryCustomers.new, invoices:)

    invoice = issue.call(customer_id: 1, subtotal_cents: 4200)

    assert_equal(
      {
        id: 1,
        customer_id: 1,
        subtotal_cents: 4200,
        tax_cents: 420,
        total_cents: 4620,
      },
      invoice.to_h,
    )
    expected_records = [
      { id: 1, customer_id: 1, subtotal_cents: 4200, tax_cents: 420 },
    ]
    assert_equal expected_records, invoices.records
  end

  def test_invalid_subtotals_never_reach_storage
    invoices = MemoryInvoices.new
    issue = Billing::IssueInvoice.new(customers: MemoryCustomers.new, invoices:)

    [-1, 1.5, '4200', nil].each do |subtotal|
      error =
        assert_raises(Billing::InvalidInvoice) do
          issue.call(customer_id: 1, subtotal_cents: subtotal)
        end
      assert_equal(
        { subtotal_cents: ['must be a non-negative integer'] },
        error.errors,
      )
    end
    assert_empty invoices.records
  end

  def test_pricing_uses_integer_cents_and_rounds_half_up
    issue =
      Billing::IssueInvoice.new(
        customers: MemoryCustomers.new,
        invoices: MemoryInvoices.new,
      )

    assert_equal 0, issue.call(customer_id: 1, subtotal_cents: 0).total_cents
    assert_equal 6, issue.call(customer_id: 1, subtotal_cents: 5).total_cents
    assert_equal 17, issue.call(customer_id: 1, subtotal_cents: 15).total_cents
    assert_equal 900_719_925_474_100,
                 issue.call(
                   customer_id: 1,
                   subtotal_cents: 9_007_199_254_740_995,
                 ).tax_cents
  end

  def test_reading_an_issued_invoice_keeps_its_stored_tax
    invoice =
      Billing::Invoice.new(
        customer_id: 1,
        id: 7,
        subtotal_cents: 4200,
        tax_cents: 210,
      )

    assert_equal 4410, invoice.total_cents
    assert invoice.frozen?
  end

  def test_repository_failures_reach_the_importer
    failure = Class.new(StandardError).new('storage unavailable')
    repository = Object.new
    repository.define_singleton_method(:create) { |**| raise failure }
    issue =
      Billing::IssueInvoice.new(
        customers: MemoryCustomers.new,
        invoices: repository,
      )

    assert_same failure,
                assert_raises(failure.class) {
                  issue.call(customer_id: 1, subtotal_cents: 4200)
                }
  end

  def test_instances_keep_their_own_repositories
    first = MemoryInvoices.new
    second = MemoryInvoices.new
    Billing::IssueInvoice.new(
      customers: MemoryCustomers.new,
      invoices: first,
    ).call(customer_id: 1, subtotal_cents: 100)
    Billing::IssueInvoice.new(
      customers: MemoryCustomers.new,
      invoices: second,
    ).call(customer_id: 1, subtotal_cents: 200)

    assert_equal 100, first.records.fetch(0).fetch(:subtotal_cents)
    assert_equal 200, second.records.fetch(0).fetch(:subtotal_cents)
  end
end
