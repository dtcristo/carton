# frozen_string_literal: true

module Shop
  class Routes < Hanami::Routes
    slice :billing, at: '/' do
      post '/invoices.json', to: 'invoices.create'
      get '/invoices/:id.json', to: 'invoices.show'
      get '/invoices/:id', to: 'invoices.show'
    end
    slice :customers, at: '/' do
      post '/customers', to: 'customers.create'
    end
  end
end
