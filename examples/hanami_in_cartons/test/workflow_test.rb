# frozen_string_literal: true

require_relative 'test_helper'

class HanamiWorkflowTest < Minitest::Test
  def setup
    @http = Rack::MockRequest.new(HanamiTestBoot::App)
  end

  def test_invalid_names_and_envelopes
    ['', '  '].each do |name|
      response = @http.post('/customers', params: { customer: { name: name } })
      assert_equal 422, response.status, response.body
      assert JSON.parse(response.body).fetch('errors').key?('name')
    end
    %w[/customers /invoices.json]
      .zip(%w[customer invoice])
      .each do |path, key|
        [nil, 'invalid', []].each do |value|
          response = post_json(path, key => value)
          assert_equal 400, response.status, response.body
        end
      end
  end

  def test_invalid_subtotals_and_customer_ids
    customer_id = register_customer('Ada').fetch('id')
    [-1, 1.5, true, '1.5', 'bad', ''].each do |subtotal|
      response =
        post_json(
          '/invoices.json',
          invoice: {
            customer_id: customer_id,
            subtotal_cents: subtotal,
          },
        )
      assert_equal 422, response.status, "#{subtotal.inspect}: #{response.body}"
      assert JSON.parse(response.body).fetch('errors').key?('subtotal_cents')
    end
    [nil, 0, -1, 1.5, true, 'bad'].each do |id|
      response =
        post_json(
          '/invoices.json',
          invoice: {
            customer_id: id,
            subtotal_cents: 4200,
          },
        )
      assert_equal 422, response.status, "#{id.inspect}: #{response.body}"
    end
  end

  def test_missing_customers_and_invoices
    response =
      post_json(
        '/invoices.json',
        invoice: {
          customer_id: 999_999,
          subtotal_cents: 4200,
        },
      )
    assert_equal 404, response.status
    assert_equal 404, @http.get('/invoices/999999.json').status
    assert_equal 422, @http.get('/invoices/invalid.json').status
  end

  def test_tax_rounds_half_up_and_accepts_zero
    customer_id = register_customer('Ada').fetch('id')
    { 0 => 0, 4 => 0, 5 => 1, 15 => 2 }.each do |subtotal, tax|
      response =
        post_json(
          '/invoices.json',
          invoice: {
            customer_id: customer_id,
            subtotal_cents: subtotal,
          },
        )
      assert_equal 201, response.status, response.body
      assert_equal tax, JSON.parse(response.body).fetch('tax_cents')
    end
  end

  def test_templates_escape_customer_names_and_preserve_stored_tax
    customer_id = register_customer('<script>alert(1)</script>').fetch('id')
    # A previously persisted invoice keeps its historical tax rather than repricing.
    row =
      HanamiTestBoot::App.slices[:billing]['repos.invoice_repo'].create(
        customer_id: customer_id,
        subtotal_cents: 4200,
        tax_cents: 210,
      )
    response = @http.get("/invoices/#{row.id}")
    assert_equal 200, response.status
    assert_includes response.body, '&lt;script&gt;alert(1)&lt;/script&gt;'
    refute_includes response.body, '<script>'
    assert_includes response.body, '$44.10'
    invoice = JSON.parse(@http.get("/invoices/#{row.id}.json").body)
    assert_equal 210, invoice.fetch('tax_cents')
    assert_equal 4410, invoice.fetch('total_cents')
  end

  def test_slice_source_stays_in_its_carton_with_shared_dependencies
    app = HanamiTestBoot::App
    customers = app.slices[:customers]
    billing = app.slices[:billing]
    customer_box = customers['actions.customers.create'].method(:handle).box
    billing_box = billing['actions.invoices.create'].method(:handle).box
    # Dry::Operation prepends a shared result wrapper; its super method is our body.
    assert_same customer_box,
                customers['operations.register_customer']
                  .method(:call)
                  .super_method
                  .box
    assert_same customer_box, customers['repos.customer_repo'].method(:get).box
    assert_same billing_box,
                billing['operations.issue_invoice']
                  .method(:call)
                  .super_method
                  .box
    assert_same billing_box, billing['repos.invoice_repo'].method(:get).box
    assert_same customers['db.gateway'], billing['db.gateway']
    refute_same customer_box, billing_box
    refute_same customer_box, app.method(:call).box
    refute_same Ruby::Box.main, customer_box
    assert_same customer_box, billing['customer_directory'].method(:find).box
    %i[Hanami Dry ROM Shop Customers Billing].each do |name|
      refute Object.const_defined?(name, false), "#{name} leaked into Main"
      refute Ruby::Box.master.const_defined?(name, false),
             "#{name} leaked into Master"
    end
    assert_raises(NameError) { billing.namespace::TaxPolicy }
  end

  def test_issues_and_reads_an_invoice
    http = Rack::MockRequest.new(HanamiTestBoot::App)
    customer =
      JSON.parse(
        http.post('/customers', params: { customer: { name: 'Ada' } }).body,
      )
    response =
      http.post(
        '/invoices.json',
        params: {
          invoice: {
            customer_id: customer.fetch('id'),
            subtotal_cents: '4200',
          },
        },
      )
    assert_equal 201, response.status, response.body
    invoice = JSON.parse(response.body)
    assert_equal 420, invoice.fetch('tax_cents')
    assert_equal 4620, invoice.fetch('total_cents')
    assert_equal invoice,
                 JSON.parse(
                   http.get("/invoices/#{invoice.fetch('id')}.json").body,
                 )
    html = http.get("/invoices/#{invoice.fetch('id')}")
    assert_equal 200, html.status
    assert_includes html.body, 'Ada'
    assert_includes html.body, '$46.20'
  end

  def test_registers_a_customer
    http = Rack::MockRequest.new(HanamiTestBoot::App)
    response =
      http.post('/customers', params: { customer: { name: '  Ada  ' } })
    assert_equal 201, response.status, response.body
    assert_equal 'Ada', JSON.parse(response.body).fetch('name')
  end

  private

  def post_json(path, attributes)
    @http.post(
      path,
      'CONTENT_TYPE' => 'application/json',
      :input => JSON.generate(attributes),
    )
  end

  def register_customer(name)
    response = post_json('/customers', customer: { name: name })
    assert_equal 201, response.status, response.body
    JSON.parse(response.body)
  end
end
