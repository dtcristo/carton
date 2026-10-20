# frozen_string_literal: true

require_relative '../test_helper'

class EnginesTest < ActionDispatch::IntegrationTest
  setup do
    Billing::InvoiceRecord.delete_all
    Customers::CustomerRecord.delete_all
  end

  test 'mounted engines register customers and issue invoices' do
    post '/customers', params: { customer: { name: '  Ada  ' } }
    assert_response :created
    customer = response.parsed_body
    assert_equal({ 'id' => customer.fetch('id'), 'name' => 'Ada' }, customer)
    post '/invoices.json',
         params: {
           invoice: {
             customer_id: customer.fetch('id'),
             subtotal_cents: '4200',
           },
         }
    assert_response :created
    invoice = response.parsed_body
    assert_equal invoice_data(
                   id: invoice.fetch('id'),
                   customer_id: customer.fetch('id'),
                 ),
                 invoice
    get "/invoices/#{invoice.fetch('id')}.json"
    assert_response :success
    assert_equal invoice, response.parsed_body
    get "/invoices/#{invoice.fetch('id')}"
    assert_includes response.body, '$46.20'
    assert_engine_bindings
  end

  test 'domain validation rejects blank names and invalid subtotals' do
    assert_invalid_envelopes
    assert_blank_names_rejected
    customer = Customers::CustomerRecord.create!(name: 'Ada')
    [-1, 1.5, 'not a number', ''].each do |subtotal|
      post '/invoices.json',
           params: {
             invoice: {
               customer_id: customer.id,
               subtotal_cents: subtotal,
             },
           },
           as: :json
      assert_response :unprocessable_content
      assert_equal(
        {
          'errors' => {
            'subtotal_cents' => ['must be a non-negative integer'],
          },
        },
        response.parsed_body,
      )
    end
    assert_equal 0, Billing::InvoiceRecord.count
  end

  test 'unknown customers cannot receive invoices' do
    post '/invoices.json',
         params: {
           invoice: {
             customer_id: 999_999,
             subtotal_cents: '4200',
           },
         }
    assert_response :not_found
    assert_equal 0, Billing::InvoiceRecord.count
  end

  test 'engine templates escape customer names and display stored tax' do
    customer = Customers::CustomerRecord.create!(name: '<Ada>')
    invoice =
      Billing::InvoiceRecord.create!(
        customer: customer,
        subtotal_cents: 4200,
        tax_cents: 210,
      )
    get "/invoices/#{invoice.id}"
    assert_response :success
    assert_includes response.body, '&lt;Ada&gt;'
    assert_includes response.body, '$44.10'
    get "/invoices/#{invoice.id}.json"
    assert_equal 210, response.parsed_body.fetch('tax_cents')
    assert_equal 4410, response.parsed_body.fetch('total_cents')
  end

  test 'application bodies stay in separate Cartons in lazy and eager modes' do
    assert_raises(NameError) { Billing::TaxPolicy }
    assert_raises(NameError) { Billing::Customers }
    customer_box = Customers::CustomerRecord.new.method(:display_name).box
    assert_same customer_box,
                Customers::CustomersController.new.method(:create).box
    billing_box = Billing::InvoicesController.new.method(:create).box
    assert_same billing_box,
                Billing::Invoice
                  .new(customer_id: 1, subtotal_cents: 0)
                  .method(:total_cents)
                  .box
    refute_same customer_box, billing_box
    refute_same Ruby::Box.current, customer_box
    refute_same Ruby::Box.main, customer_box
    refute Ruby::Box.main.eval("''.respond_to?(:blank?)")
    refute Ruby::Box.master.eval("''.respond_to?(:blank?)")
    assert_same Customers::Engine,
                Rails
                  .application
                  .railties
                  .find { |railtie| railtie.instance_of?(Customers::Engine) }
                  .class
  end

  private

  def assert_engine_bindings
    assert_same Customers::CustomerRecord,
                Billing::InvoiceRecord.reflect_on_association(:customer).klass
    assert_same Billing::InvoiceRecord,
                Customers::CustomerRecord.reflect_on_association(
                  :invoices,
                ).klass
    assert_same Customers, ShopBoot::Application.module_parent::Customers
  end

  def invoice_data(id:, customer_id:)
    {
      'id' => id,
      'customer_id' => customer_id,
      'subtotal_cents' => 4200,
      'tax_cents' => 420,
      'total_cents' => 4620,
    }
  end

  def assert_blank_names_rejected
    ['', '   '].each do |name|
      post '/customers', params: { customer: { name: name } }
      assert_response :unprocessable_content
      assert_equal(
        { 'errors' => { 'name' => ['must not be blank'] } },
        response.parsed_body,
      )
    end
    assert_equal 0, Customers::CustomerRecord.count
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
