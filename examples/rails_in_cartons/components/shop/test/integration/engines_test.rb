# frozen_string_literal: true

require_relative '../test_helper'

class EnginesTest < ActionDispatch::IntegrationTest
  setup do
    Orders::Order.delete_all
    Customers::Customer.delete_all
  end

  test 'mounted engines create and query associated records' do
    post '/customers', params: { name: 'Ada' }
    assert_response :created
    customer = response.parsed_body
    post '/orders',
         params: {
           customer_id: customer.fetch('id'),
           total_cents: 4200,
         }
    assert_response :created
    get '/orders'
    assert_response :success
    assert_equal 'Ada', response.parsed_body.first.dig('customer', 'name')
    assert_same Customers::Customer,
                Orders::Order.reflect_on_association(:customer).klass
    assert_same Orders::Order,
                Customers::Customer.reflect_on_association(:orders).klass
    assert_same Customers, ShopBoot::Application.module_parent::Customers
  end

  test 'validation failures have normal Rails errors' do
    post '/customers', params: { name: '' }
    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch('errors').fetch('name'),
                    "can't be blank"
    customer = Customers::Customer.create!(name: 'Ada')
    post '/orders', params: { customer_id: customer.id, total_cents: 0 }
    assert_response :unprocessable_content
    assert_equal 0, Orders::Order.count
  end

  test 'engine templates render with Rails escaping and domain extensions' do
    Customers::Customer.create!(name: '  <Ada>  ')
    get '/customers/directory'
    assert_response :success
    assert_includes response.body, '&lt;Ada&gt;'
    assert_equal 'Anonymous', Customers::Customer.new.display_name
  end

  test 'GlobalID jobs retain the imported model identity' do
    customer = Customers::Customer.create!(name: 'Ada')
    order = Orders::Order.create!(customer: customer, total_cents: 4200)
    serialized = Orders::ReceiptJob.new(order).serialize
    ActiveJob::Base.deserialize(serialized).perform_now
    assert order.reload.receipt_sent?
    order.update!(receipt_sent: false)
    Orders::ReceiptJob.perform_later(order)
    assert order.reload.receipt_sent?
  end

  test 'application bodies stay in separate Cartons in lazy and eager modes' do
    customer_box = Customers::Customer.new.method(:display_name).box
    controller_box = Customers::CustomersController.new.method(:create).box
    order_box = Orders::ReceiptJob.new.method(:perform).box
    assert_same customer_box, controller_box
    refute_same customer_box, order_box
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
end
