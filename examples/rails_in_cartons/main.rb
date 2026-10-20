# frozen_string_literal: true

require_relative '../../lib/carton'
require 'tmpdir'

Carton.setup_bundle
require 'rack'
require 'json'

def demonstrate(directory)
  previous_database = ENV['SHOP_DATABASE']
  ENV['SHOP_DATABASE'] = File.join(directory, 'demo.sqlite3')
  script = File.expand_path('components/shop/bin/rails', __dir__)
  unless system(RbConfig.ruby, script, 'db:prepare', out: File::NULL)
    abort 'database preparation failed'
  end

  shop = import 'shop'
  http =
    Rack::MockRequest.new(
      ->(env) { shop.call(env.merge('HTTP_HOST' => 'example.org')) },
    )
  customer = http.post('http://example.org/customers', params: { name: 'Ada' })
  abort "customer: #{customer.status}" unless customer.status == 201
  order =
    http.post(
      'http://example.org/orders',
      params: {
        customer_id: JSON.parse(customer.body).fetch('id'),
        total_cents: 4200,
      },
    )
  abort "order: #{order.status}" unless order.status == 201
  puts "GET /orders: #{http.get('http://example.org/orders').body}"
  puts "GET /customers/directory: #{http.get('http://example.org/customers/directory').status}"
  abort 'Rails leaked into Main' if defined?(Rails)
  puts 'Rails loaded in Main: false'
ensure
  ENV['SHOP_DATABASE'] = previous_database
end

Dir.mktmpdir('carton-rails-engines') { |directory| demonstrate(directory) }
