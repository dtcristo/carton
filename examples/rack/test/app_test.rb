# frozen_string_literal: true

require_relative '../../../lib/carton'

# Bundle boundary: Main uses the example's Gemfile, with its test group.
Carton.setup_bundle(:default, :test)
require 'minitest/autorun'
require 'rack'

class AppTest < Minitest::Test
  APP = Rack::Builder.parse_file(File.expand_path('../config.ru', __dir__))

  def test_catalog_lists_products
    response = request.get('/catalog')
    assert_equal 200, response.status
    assert_equal '{"tea":450,"coffee":600}', response.body
  end

  def test_orders_prices_through_the_catalog
    response = request.get('/orders/quote?sku=coffee&quantity=3')
    assert_equal '{"sku":"coffee","total":1800}', response.body
  end

  def test_unknown_sku_is_not_found
    assert_equal 404, request.get('/orders/quote?sku=cake&quantity=1').status
  end

  def test_products_stay_private
    catalog = import_relative '../cartons/catalog'
    assert_raises(NameError) { catalog::Products }
  end

  private

  def request = Rack::MockRequest.new(APP)
end
