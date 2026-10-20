# frozen_string_literal: true

Shop::Application.routes.draw do
  mount Customers::Engine => '/customers'
  mount Orders::Engine => '/orders'
end
