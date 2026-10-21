# frozen_string_literal: true

require_relative '../../lib/carton'
module ShopBoot
  App = import_relative 'shop'
end
run ShopBoot::App
