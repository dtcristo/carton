# frozen_string_literal: true

Shop::Application.routes.draw do
  mount Customers::Engine => '/customers'
  mount Billing::Engine => '/'
end
