# frozen_string_literal: true

require_relative 'config/boot'

# Carton boundary: Main receives the shop's Rack application.
module ShopBoot
  App = import 'shop'
end

run ShopBoot::App
