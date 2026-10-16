# frozen_string_literal: true

require_relative 'config/environment'

# Send one request through Rack without starting a server.
response = Rack::MockRequest.new(Rails.application).get('/invoices/42')
abort "unexpected status #{response.status}" unless response.status == 200

puts '-- GET /invoices/42 --'
puts "status = #{response.status}"
puts "body = #{response.body}"
puts
puts '-- Carton boundary --'
puts "Billing is the Carton's module: #{Billing.name}"
begin
  Billing::TaxPolicy
rescue NameError => e
  puts "Billing::TaxPolicy: #{e.message}"
end
puts "Main sees ActiveSupport core extensions: #{''.respond_to?(:blank?)}"
puts "Billing sees ActiveSupport core extensions: #{Billing.active_support_visible?}"
