# frozen_string_literal: true

Customers::Engine.routes.draw do
  get 'directory', to: 'directory#index'
  resources :customers, path: '', only: %i[index create]
end
