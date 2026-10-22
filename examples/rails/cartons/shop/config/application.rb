# frozen_string_literal: true

require_relative 'boot'

# Carton boundary: Main receives the shop's Rack application.
module ShopBoot
  Application = import 'shop'
end
