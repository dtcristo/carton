# frozen_string_literal: true

require_relative '../../lib/carton'
require 'tmpdir'

# Bundle boundary: the app's Gemfile. Main only needs rack; Rails loads in the
# framework Carton's Box.
Carton.setup_bundle
require 'rack'

Dir.mktmpdir do |directory|
  # A throwaway test database, prepared by the shop's own bin/rails.
  ENV['RAILS_ENV'] = 'test'
  ENV['SHOP_DATABASE'] = File.join(directory, 'demo.sqlite3')
  rails = File.join(__dir__, 'cartons/shop/bin/rails')
  system(RbConfig.ruby, rails, 'db:prepare', out: File::NULL, exception: true)

  # Carton boundary: Main receives the shop's Rack application.
  http = Rack::MockRequest.new(import('shop'))

  # Rails' host authorization needs a Host header that config.hosts allows.
  host = { 'HTTP_HOST' => 'example.org' }
  http.post('/customers', host.merge(params: { customer: { name: 'Ada' } }))
  invoice = { customer_id: 1, subtotal_cents: 4200 }
  puts 'POST /invoices.json: ' \
         "#{http.post('/invoices.json', host.merge(params: { invoice: })).body}"
  puts "GET /invoices/1: #{http.get('/invoices/1', host).status}"
  puts "Rails loaded in Main: #{!defined?(Rails).nil?}"
end
