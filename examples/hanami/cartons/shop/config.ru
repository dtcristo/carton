# frozen_string_literal: true

require_relative 'config/boot'

module ShopBoot
  App = import 'shop'
end

run ShopBoot::App
