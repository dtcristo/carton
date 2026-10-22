# frozen_string_literal: true

require_relative '../../lib/carton'
require 'tmpdir'

# Bundle boundary: the app's Gemfile. Main only needs rack; Hanami loads in
# the framework Carton's Box.
Carton.setup_bundle
require 'rack'

Dir.mktmpdir do |directory|
  # A throwaway test database, migrated by the shop's own bin/hanami.
  ENV['HANAMI_ENV'] = 'test'
  ENV['DATABASE_URL'] = "sqlite://#{directory}/shop.sqlite3"
  hanami = File.join(__dir__, 'cartons/shop/bin/hanami')
  # Migrate with lazy loading: eager loading would boot repos before their
  # tables exist.
  system(
    { 'HANAMI_EAGER_LOAD' => 'false' },
    RbConfig.ruby,
    hanami,
    'db',
    'migrate',
    out: File::NULL,
    exception: true,
  )

  # Carton boundary: Main receives the shop's Rack application.
  app = import 'shop'
  http = Rack::MockRequest.new(app)

  http.post('/customers', params: { customer: { name: 'Ada' } })
  invoice = { customer_id: 1, subtotal_cents: 4200 }
  puts "POST /invoices.json: #{http.post('/invoices.json', params: { invoice: }).body}"
  puts "GET /invoices/1: #{http.get('/invoices/1').status}"
  puts "Hanami loaded in Main: #{!defined?(Hanami).nil?}"
ensure
  app&.shutdown
end
