# frozen_string_literal: true

require_relative '../../lib/carton'
require 'tmpdir'

Carton.setup_bundle

require 'rack'
require 'json'

def demonstrate(directory)
  previous = %w[DATABASE_URL HANAMI_ENV].to_h { |key| [key, ENV[key]] }
  ENV['DATABASE_URL'] = "sqlite://#{directory}/shop.sqlite3"
  ENV['HANAMI_ENV'] = 'test'

  script = File.expand_path('components/shop/bin/hanami', __dir__)
  unless system(
           { 'HANAMI_EAGER_LOAD' => 'false' },
           RbConfig.ruby,
           script,
           'db',
           'migrate',
           out: File::NULL,
         )
    abort 'migration failed'
  end

  app = import 'shop'
  http = Rack::MockRequest.new(app)

  customer = http.post('/customers', params: { customer: { name: 'Ada' } })
  abort customer.body unless customer.status == 201

  invoice =
    http.post(
      '/invoices.json',
      params: {
        invoice: {
          customer_id: JSON.parse(customer.body).fetch('id'),
          subtotal_cents: '4200',
        },
      },
    )
  abort invoice.body unless invoice.status == 201

  puts "POST /invoices.json: #{invoice.body}"
  puts "GET /invoices/1: #{http.get('/invoices/1').status}"
  abort 'Hanami leaked into Main' if defined?(Hanami)
  puts 'Hanami loaded in Main: false'
ensure
  app&.shutdown
  %w[DATABASE_URL HANAMI_ENV].each { |key| ENV[key] = previous[key] }
end

Dir.mktmpdir('carton-hanami') { |directory| demonstrate(directory) }
