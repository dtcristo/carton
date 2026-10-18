# frozen_string_literal: true

require_relative '../../lib/carton'

# Import the billing Carton: billing.rb plus everything in billing/.
Billing = import_relative 'billing'
puts "Invoice total: #{Billing.invoice(40).total}"

# A Bare Carton comes back as a Carton::Namespace of what it defines.
MathTools = import_relative 'math'
puts "10% of 40: #{MathTools.percent(40, 10)} (math #{MathTools::VERSION})"

begin
  Billing::Tax # steep:ignore UnknownConstant
rescue NameError
  puts 'Billing::Tax is private'
end

# Only a Carton's Entrypoint can be imported, never a file inside it.
begin
  import_relative 'billing/invoice'
rescue Carton::ImportError => e
  puts e.message.gsub("#{__dir__}/", '')
end
