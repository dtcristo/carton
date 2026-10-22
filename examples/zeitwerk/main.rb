# frozen_string_literal: true

require_relative '../../lib/carton'

# Bundle boundary: the app's Gemfile gives the Main Box zeitwerk 2.8.3.
Carton.setup_bundle
require 'zeitwerk'

# The app's own Zeitwerk loader, in the Main Box, for the app's code in lib/.
# The shipping Carton lives in lib/ too, so ignore it: otherwise this loader
# autoloads lib/shipping.rb in the Main Box, outside any Carton.
lib = File.join(__dir__, 'lib')
app_loader = Zeitwerk::Loader.new
app_loader.push_dir(lib)
app_loader.ignore(File.join(lib, 'shipping.rb'), File.join(lib, 'shipping'))
app_loader.setup

# Carton boundary: each import runs a Carton's Entrypoint in its own Box,
# where it sets up its own Zeitwerk loader.
Billing = import_relative 'cartons/billing'
Shipping = import_relative 'lib/shipping'

puts "Main Box zeitwerk: #{Zeitwerk::VERSION}"
puts "billing zeitwerk: #{Billing.zeitwerk_version}"
puts "shipping zeitwerk has nsfiles: #{Shipping.zeitwerk_nsfiles?}"

# OrderSummary is the app's own code, autoloaded in the Main Box. It calls
# both Cartons through their Exports.
puts OrderSummary.line(4200, 3)
