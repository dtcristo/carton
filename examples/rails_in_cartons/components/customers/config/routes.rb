# frozen_string_literal: true

Customers::Engine.routes.draw { resources :customers, path: '', only: :create }
