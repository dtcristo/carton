# frozen_string_literal: true

require 'json'
require 'uri'

# Carton boundary: orders reaches the catalog only through its Export. The
# host imports catalog too, so both share one Carton.
Catalog = import_relative '../../catalog'

# The Rack app: GET /orders/quote?sku=tea&quantity=2 prices an order.
Orders =
  lambda do |env|
    params = URI.decode_www_form(env['QUERY_STRING']).to_h
    price = Catalog.price(params['sku'])
    next 404, { 'content-type' => 'text/plain' }, ['Unknown SKU'] unless price

    quote = { sku: params['sku'], total: price * Integer(params['quantity']) }
    [200, { 'content-type' => 'application/json' }, [quote.to_json]]
  end

# Export: a lambda is a Rack app too.
export Orders
