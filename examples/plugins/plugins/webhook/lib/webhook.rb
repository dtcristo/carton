# frozen_string_literal: true

# Carton boundary: this Entrypoint and everything it loads run in the webhook
# plugin's own Box. The host only gets the module exported below.

# Bundle boundary: plugins/webhook/Gemfile locks faraday 2.15.0. Bundler
# activates it in this Box only, beside crm_client's 1.10.6.
Carton.setup_bundle
require 'faraday'

module Webhook
  URL = 'https://hooks.example.com'

  # A stand-in for the real service, so the example runs offline.
  STUBS =
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.post('/month-end') do |env|
        months = JSON.parse(env.body).size
        [202, { 'Content-Type' => 'application/json' }, { months: }.to_json]
      end
    end
  private_constant :STUBS

  def self.title = "Webhook (faraday #{Faraday::VERSION})"

  def self.call(orders)
    totals =
      orders
        .group_by { it.fetch(:month) }
        .sort
        .to_h { |month, rows| [month, rows.sum { it.fetch(:amount) }] }
    response = connection.post('/month-end', totals)

    [
      *totals.map { |month, total| "#{month}  #{total}" },
      "POST /month-end  #{response.status}  #{response.body['months']} months",
    ]
  end

  # `request :authorization, :basic, ...` is new in faraday 2, so this plugin
  # cannot run on the 1.10 that crm_client needs.
  def self.connection
    Faraday.new(URL) do |f|
      f.request :authorization, :basic, 'reports', 'secret'
      f.request :json
      f.response :json
      f.adapter :test, STUBS
    end
  end

  private_class_method :connection
end

# Export: the plugin interface is this module's `title` and `call`.
export Webhook
