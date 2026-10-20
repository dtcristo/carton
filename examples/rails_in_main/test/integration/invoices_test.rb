# frozen_string_literal: true

require_relative '../test_helper'

class InvoicesTest < ActionDispatch::IntegrationTest
  setup { Invoice.delete_all }

  test 'Rails persists invoices and the Carton calculates their totals' do
    post '/invoices.json', params: { invoice: { subtotal_cents: 4200 } }
    assert_response :created
    assert_equal 4620, response.parsed_body.fetch('total_cents')
    invoice = Invoice.find(response.parsed_body.fetch('id'))
    assert_equal 4200, invoice.subtotal_cents
    get "/invoices/#{invoice.id}.json"
    assert_response :success
    assert_equal invoice.quote.to_h.transform_keys(&:to_s), response.parsed_body
    assert_same Shop::Billing::Invoice, invoice.quote.class
  end

  test 'HTML templates use normal Rails helpers' do
    invoice = Invoice.create!(subtotal_cents: 4200)
    get "/invoices/#{invoice.id}"
    assert_response :success
    assert_includes response.body, '$46.20'
  end

  test 'invalid invoice returns normal model errors' do
    post '/invoices.json', params: { invoice: { subtotal_cents: -1 } }
    assert_response :unprocessable_content
    assert_includes response.parsed_body.fetch('errors'), 'subtotal_cents'
    assert_equal 0, Invoice.count
  end

  test 'Active Job round trips the host record through GlobalID' do
    invoice = Invoice.create!(subtotal_cents: 4200)
    serialized = InvoiceAuditJob.new(invoice).serialize
    ActiveJob::Base.deserialize(serialized).perform_now
    assert invoice.reload.audited_at
    invoice.update!(audited_at: nil)
    InvoiceAuditJob.perform_later(invoice)
    assert invoice.reload.audited_at
  end

  test 'Billing stays private and separate from the Rails runtime' do
    assert_raises(NameError) { Shop::Billing::TaxPolicy }
    refute Shop::Billing.active_support_visible?
    quote_box =
      Shop::Billing::Invoice
        .new(id: 1, subtotal_cents: 4200)
        .method(:total_cents)
        .box
    refute_same Ruby::Box.main, quote_box
    refute quote_box.eval('Object.const_defined?(:Rails, false)')
    refute quote_box.eval('Object.const_defined?(:ApplicationRecord, false)')
    assert_same Ruby::Box.main, Invoice.new.method(:quote).box
  end
end
