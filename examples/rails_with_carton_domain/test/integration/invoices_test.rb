# frozen_string_literal: true

require_relative '../test_helper'

class InvoicesTest < ActionDispatch::IntegrationTest
  setup do
    Invoice.delete_all
    Customer.delete_all
  end

  test 'the two Cartons register a customer and issue a persisted invoice' do
    post '/customers', params: { customer: { name: '  Ada  ' } }
    assert_response :created
    customer = response.parsed_body
    assert_equal 'Ada', customer.fetch('name')
    post '/invoices.json',
         params: {
           invoice: {
             customer_id: customer.fetch('id'),
             subtotal_cents: '4200',
           },
         }
    assert_response :created
    invoice = response.parsed_body
    expected = {
      'id' => invoice.fetch('id'),
      'customer_id' => customer.fetch('id'),
      'subtotal_cents' => 4200,
      'tax_cents' => 420,
      'total_cents' => 4620,
    }
    assert_equal expected, invoice
    get "/invoices/#{invoice.fetch('id')}.json"
    assert_response :success
    assert_equal expected, response.parsed_body
    assert_storage_associations
  end

  test 'HTML escapes customer names and retains the stored tax amount' do
    customer = Customer.create!(name: '<Ada>')
    invoice = Invoice.create!(customer:, subtotal_cents: 4200, tax_cents: 210)
    get "/invoices/#{invoice.id}"
    assert_response :success
    assert_includes response.body, '&lt;Ada&gt;'
    assert_includes response.body, '$44.10'
  end

  test 'domain validation rejects invalid customers and invoices before storage' do
    assert_invalid_envelopes
    post '/customers', params: { customer: { name: '  ' } }
    assert_response :unprocessable_content
    assert_equal ['must not be blank'],
                 response.parsed_body.fetch('errors').fetch('name')
    assert_equal 0, Customer.count
    customer = Customer.create!(name: 'Ada')
    [-1, 1.5, 'not a number'].each do |subtotal|
      post '/invoices.json',
           params: {
             invoice: {
               customer_id: customer.id,
               subtotal_cents: subtotal,
             },
           },
           as: :json
      assert_response :unprocessable_content
      assert_equal ['must be a non-negative integer'],
                   response.parsed_body.fetch('errors').fetch('subtotal_cents')
    end
    assert_equal 0, Invoice.count
  end

  test 'unknown customers cannot receive invoices' do
    post '/invoices.json',
         params: {
           invoice: {
             customer_id: 999_999,
             subtotal_cents: 4200,
           },
         }
    assert_response :not_found
    assert_equal 0, Invoice.count
  end

  test 'both domains stay private and separate from the Rails runtime' do
    assert_raises(NameError) { Shop::Billing::TaxPolicy }
    assert_raises(NameError) { Shop::Billing::Customers }
    refute Shop::Billing.active_support_visible?
    billing_box =
      Shop::Billing::Invoice
        .new(customer_id: 1, subtotal_cents: 4200)
        .method(:total_cents)
        .box
    customers_box =
      Shop::Customers::Customer.new(id: 1, name: 'Ada').method(:to_h).box
    refute_same Ruby::Box.main, billing_box
    refute_same billing_box, customers_box
    [billing_box, customers_box].each do |box|
      refute box.eval('Object.const_defined?(:Rails, false)')
      refute box.eval('Object.const_defined?(:ApplicationRecord, false)')
      refute box.eval("''.respond_to?(:blank?)")
    end
    assert_same Ruby::Box.main, InvoiceRepository.new.method(:create).box
    assert_same Ruby::Box.main, InvoicesController.new.method(:create).box
  end

  private

  def assert_storage_associations
    assert_equal Customer, Invoice.reflect_on_association(:customer).klass
    assert_equal Invoice, Customer.reflect_on_association(:invoices).klass
  end

  def assert_invalid_envelopes
    [
      ['/customers', :customer],
      ['/invoices.json', :invoice],
    ].each do |path, key|
      post path, params: { key => 'invalid' }, as: :json
      assert_response :bad_request
    end
  end
end
