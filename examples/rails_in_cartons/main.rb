# frozen_string_literal: true

require_relative '../../lib/carton'

# The Main Box is the server: it loads Rack, not Rails.
Carton.setup_bundle
require 'rack'

Shop = import 'shop'
http = Rack::MockRequest.new(Shop)

# Print each response and fail on an unexpected status.
def show(label, response, status)
  puts "#{label}: #{response.status} #{response.body}"
  abort "expected #{status}" unless response.status == status
end

show 'POST /customers', http.post('/customers', params: { name: 'Ada' }), 201
show 'POST /orders',
     http.post('/orders', params: { customer_id: 1, total_cents: 4_200 }),
     201
show 'POST /orders (invalid)',
     http.post('/orders', params: { customer_id: 1, total_cents: 0 }),
     422
show 'GET /orders', http.get('/orders'), 200
puts
puts "Rails loaded in the Main Box: #{!defined?(Rails).nil?}"
