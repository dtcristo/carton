# frozen_string_literal: true

require_relative '../../lib/carton'
require 'tmpdir'

Carton.setup_bundle
require 'rack'
require 'json'

def demonstrate(directory)
  previous_database = ENV['SHOP_DATABASE']
  previous_environment = ENV['RAILS_ENV']
  ENV['SHOP_DATABASE'] = File.join(directory, 'demo.sqlite3')
  ENV['RAILS_ENV'] = 'test'
  script = File.expand_path('components/shop/bin/rails', __dir__)
  unless system(RbConfig.ruby, script, 'db:prepare', out: File::NULL)
    abort 'database preparation failed'
  end

  shop = import 'shop'
  http =
    Rack::MockRequest.new(
      ->(env) { shop.call(env.merge('HTTP_HOST' => 'example.org')) },
    )
  customer =
    http.post(
      'http://example.org/customers',
      params: {
        customer: {
          name: 'Ada',
        },
      },
    )
  abort "customer: #{customer.status}" unless customer.status == 201
  invoice =
    http.post(
      'http://example.org/invoices.json',
      params: {
        invoice: {
          customer_id: JSON.parse(customer.body).fetch('id'),
          subtotal_cents: '4200',
        },
      },
    )
  abort "invoice: #{invoice.status}" unless invoice.status == 201
  puts "POST /invoices: #{invoice.body}"
  puts "GET /invoices/1: #{http.get('http://example.org/invoices/1').status}"
  abort 'Rails leaked into Main' if defined?(Rails)
  puts 'Rails loaded in Main: false'
ensure
  ENV['SHOP_DATABASE'] = previous_database
  ENV['RAILS_ENV'] = previous_environment
end

Dir.mktmpdir('carton-rails-engines') { |directory| demonstrate(directory) }
