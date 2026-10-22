# frozen_string_literal: true

# Carton boundary: crm's vendored API client. It is a Transitive Carton for the
# host, which reaches it only through the crm plugin.

# Bundle boundary: crm_client/Gemfile locks faraday 1.10.6. Bundler activates
# it in this Box only, so the crm plugin and the host never see it.
Carton.setup_bundle
require 'faraday'

module CrmClient
  URL = 'https://crm.example.com'

  # A stand-in for the real service, so the example runs offline.
  STUBS =
    Faraday::Adapter::Test::Stubs.new do |stub|
      stub.put(%r{\A/accounts/\w+/sales\z}) { [200, {}, 'synced'] }
    end
  private_constant :STUBS

  def self.faraday_version = Faraday::VERSION

  def self.sync(account, total)
    connection.put("/accounts/#{account}/sales", total: total.to_s).body
  end

  # Written against faraday 1. `request :basic_auth` was removed in 2.0, so
  # this client cannot move to the version the webhook plugin needs.
  def self.connection
    Faraday.new(URL) do |f|
      f.request :basic_auth, 'reports', 'secret'
      f.request :url_encoded
      f.adapter :test, STUBS
    end
  end

  private_class_method :connection
end

# Export: the client's Public Surface is `faraday_version` and `sync`.
export CrmClient
