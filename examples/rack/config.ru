# frozen_string_literal: true

require_relative '../../lib/carton'

# The host app: plain Rack routing in the Main Box. Each Carton exports a Rack
# app, an object that responds to `call(env)`.

# Carton boundary: each import loads one Carton in its own Box. Only its
# Export comes back.
map '/catalog' do
  run import_relative('cartons/catalog')
end

map '/orders' do
  run import_relative('cartons/orders')
end
