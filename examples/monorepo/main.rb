# frozen_string_literal: true

require_relative '../../lib/carton'

# One Gemfile for the whole monorepo. Bundler puts each Carton's lib/ on the
# load path, so Cartons are imported by gem name.
Carton.setup_bundle

# Each import loads one Carton in its own Box.
Billing = import 'billing'
Shipping = import 'shipping'
Pricing = import 'pricing'

puts Billing.invoice(42, %w[19.99 5.01])
puts "Shipping for 3 kg: #{Shipping.quote(3)}"
puts "Pricing uses bigdecimal #{Pricing.bigdecimal_version}"
puts

# Billing imported pricing first; the app gets the same Carton.
puts "Billing and the app share one pricing Carton: #{Billing::Pricing.equal?(Pricing)}"

begin
  Pricing::Rounding
rescue NameError => e
  puts "Pricing::Rounding is private: #{e.message.lines.first.strip}"
end

puts "bigdecimal loaded in the Main Box: #{!defined?(BigDecimal).nil?}"
