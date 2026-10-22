# frozen_string_literal: true

require 'carton'

# Resolved by the app's lockfile, so every Carton sees the same version.
require 'faraday'

module Shipping
  # A stand-in for the carrier's API, so the example runs offline.
  STUBS =
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get('/rates') do
        [200, { 'Content-Type' => 'application/json' }, '{"per_kg":4}']
      end
    end
  private_constant :STUBS

  def self.quote(kilograms)
    kilograms * connection.get('/rates').body.fetch('per_kg')
  end

  def self.faraday_version = Faraday::VERSION

  def self.connection
    Faraday.new('https://carrier.example.com') do |f|
      f.response :json
      f.adapter :test, STUBS
    end
  end

  private_class_method :connection
end

# Export: the Carton's root module.
export Shipping
