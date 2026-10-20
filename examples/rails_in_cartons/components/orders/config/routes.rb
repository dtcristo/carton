# frozen_string_literal: true

Orders::Engine.routes.draw do
  resources :orders, path: '', only: %i[index create]
end
