# frozen_string_literal: true

Rails.application.routes.draw { resources :invoices, only: %i[create show] }
