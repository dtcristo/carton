# frozen_string_literal: true

require 'tmpdir'

def demonstrate(directory)
  previous_database = ENV['MAIN_DATABASE']
  ENV['MAIN_DATABASE'] = File.join(directory, 'demo.sqlite3')
  script = File.expand_path('bin/rails', __dir__)
  unless system(RbConfig.ruby, script, 'db:prepare', out: File::NULL)
    abort 'database preparation failed'
  end
  require_relative 'config/environment'
  invoice = Invoice.create!(subtotal_cents: 4200)
  http = Rack::MockRequest.new(Rails.application)
  response =
    http.get(
      "http://example.org/invoices/#{invoice.id}.json",
      'HTTP_HOST' => 'example.org',
    )
  abort "unexpected status #{response.status}" unless response.status == 200
  puts "GET /invoices/#{invoice.id}.json: #{response.body}"
  puts "HTML view: #{http.get("http://example.org/invoices/#{invoice.id}", 'HTTP_HOST' => 'example.org').status}"
  puts "Main sees Active Support: #{''.respond_to?(:blank?)}"
  puts "Billing sees Active Support: #{Shop::Billing.active_support_visible?}"
ensure
  ENV['MAIN_DATABASE'] = previous_database
end

Dir.mktmpdir('carton-rails-main-demo') { |directory| demonstrate(directory) }
