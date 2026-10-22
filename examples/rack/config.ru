# frozen_string_literal: true

require_relative '../../lib/carton'

# The host app: plain Rack routing in the Main Box. Each Carton exports a Rack
# app, an object that responds to `call(env)`.

# Carton boundary: each import loads one Carton in its own Box. Only its
# Export comes back. Rack evaluates this file, and import_relative cannot
# infer a path from evaluated code, so import absolute paths, marked for
# `carton check`.
map '/catalog' do
  run import(File.join(__dir__, 'cartons/catalog')) # carton:dynamic
end

map '/orders' do
  run import(File.join(__dir__, 'cartons/orders')) # carton:dynamic
end
