# frozen_string_literal: true

module Customers
  class ApplicationController < Framework::BrowserController
    protect_from_forgery with: :exception
    skip_forgery_protection if Framework::Rails.env.test?
  end
end
