# frozen_string_literal: true

require_relative '../../lib/carton'

# Bundle boundary: the host's Gemfile provides rack. The Cartons use none of
# its gems.
Carton.setup_bundle
require 'rack'

# Builds the same app `rackup` serves from config.ru.
app = Rack::Builder.parse_file(File.join(__dir__, 'config.ru'))
request = Rack::MockRequest.new(app)

puts "GET /catalog => #{request.get('/catalog').body}"
puts "GET /orders/quote?sku=tea&quantity=2 => " \
       "#{request.get('/orders/quote?sku=tea&quantity=2').body}"
puts "GET /orders/quote?sku=cake&quantity=1 => " \
       "#{request.get('/orders/quote?sku=cake&quantity=1').status}"
puts

# Carton boundary: a Shared Import returns the Export config.ru mounted.
Catalog = import_relative 'cartons/catalog'

begin
  Catalog::Products
rescue NameError => e
  puts "Catalog::Products is private: #{e.message.lines.first.strip}"
end

puts "JSON loaded in the Main Box: #{!defined?(JSON).nil?}"
