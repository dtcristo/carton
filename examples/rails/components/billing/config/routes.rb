# frozen_string_literal: true

Billing::Engine.routes.draw { resources :invoices, only: %i[create show] }
