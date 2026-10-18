# frozen_string_literal: true

require_relative '../../lib/carton'

# The app's bundle (Gemfile): carton and zeitwerk 2.8.3, for the Main Box.
Carton.setup_bundle
require 'zeitwerk'

# Prints a result, and raises if the behavior this example documents changed.
def show(label, value, expected)
  unless value == expected
    raise "#{label}: expected #{expected.inspect}, got #{value.inspect}"
  end

  puts "#{label} = #{value}"
end

def relative(dirs) = dirs.map { |dir| dir.delete_prefix("#{__dir__}/") }

main_box = Ruby::Box.main

# The app's own Zeitwerk loader, in the Main Box, for the app's own code in
# lib/. The shipping Carton lives in lib/ too, so ignore it: otherwise this
# loader autoloads lib/shipping.rb in the Main Box, outside any Carton.
lib = File.join(__dir__, 'lib')
app_loader = Zeitwerk::Loader.new
app_loader.push_dir(lib)
app_loader.ignore(File.join(lib, 'shipping.rb'), File.join(lib, 'shipping'))
app_loader.setup

puts '-- The app loader ignores the shipping Carton --'
show 'Main Box autoload for Shipping',
     Object.autoload?(:Shipping).inspect,
     'nil'
puts

# Each import runs a Carton's Entrypoint in its own Box, where it sets up its
# own Zeitwerk loader.
Billing = import_relative 'cartons/billing'
Shipping = import_relative 'lib/shipping'

puts '-- Each Box has its own Zeitwerk --'
show 'Main Box zeitwerk', Zeitwerk::VERSION, '2.8.3'
show 'billing zeitwerk', Billing.zeitwerk_version, '2.7.5'
show 'Main Box loader dirs', relative(Zeitwerk::Loader.all_dirs), %w[lib]
show 'billing loader dirs',
     relative(Billing.zeitwerk_dirs),
     %w[cartons/billing/lib]
show 'shipping loader dirs', relative(Shipping.zeitwerk_dirs), %w[lib/shipping]
# nsfiles arrived in Zeitwerk 2.8, so only the shipping Box has them.
show 'billing zeitwerk has nsfiles', Billing.zeitwerk_nsfiles?, false
show 'shipping zeitwerk has nsfiles', Shipping.zeitwerk_nsfiles?, true
puts

puts '-- Eager loading runs in the Carton\'s Box --'
show 'Billing::Invoice loaded in the Main Box',
     Billing::Invoice::LOADED_IN.equal?(main_box),
     false
show 'Shipping::Rate loaded in the Main Box',
     Shipping::Rate::LOADED_IN.equal?(main_box),
     false
# The app's eager load covers only lib/ minus the ignored Carton.
app_loader.eager_load
show 'Carton files in the Main Box\'s $LOADED_FEATURES',
     $LOADED_FEATURES.grep(%r{/(billing|shipping)(/|\.rb)}).size,
     0
puts

puts '-- A lazy namespace defined in an nsfile --'
# Shipping::Carriers is excluded from eager loading, so this line triggers its
# autoload, which points at carriers/ns.rb, from the Main Box. ns.rb runs in
# the shipping Carton's Box, and Zeitwerk then defines Post's autoload there.
show 'Shipping::Carriers autoloads',
     relative([Shipping.autoload?(:Carriers)]).first,
     'lib/shipping/carriers/ns.rb'
show 'Shipping::Carriers loaded in the Main Box',
     Shipping::Carriers::LOADED_IN.equal?(main_box),
     false
show 'Shipping::Carriers::Post loaded in the Main Box',
     Shipping::Carriers::Post::LOADED_IN.equal?(main_box),
     false
show 'ns.rb defines a constant of its own',
     Shipping::Carriers.const_defined?(:Ns, false),
     false
puts

puts '-- The app\'s own code, autoloaded in the Main Box --'
show 'OrderSummary.line(4200, 3)',
     OrderSummary.line(4200, 3),
     'invoice $42.00 + shipping $11.00'
puts

puts '-- A lazy autoload still runs in the Carton\'s Box --'
# Billing::Archive is excluded from eager loading, so this line triggers its
# autoload from the Main Box. archive.rb still runs in the billing Carton's
# Box, where the autoload was defined.
show 'Billing::Archive loaded in the Main Box',
     Billing::Archive::LOADED_IN.equal?(main_box),
     false
puts

puts '-- Reloading a Carton --'
held_rate_class = Shipping::Rate # an importer keeping a reference
old_rate = Shipping::Rate.new
old_carriers = Shipping::Carriers
Shipping.reload!
# Shipping is the same module, and its loader defined a fresh Rate in it.
show 'Shipping is the same module',
     import_relative('lib/shipping').equal?(Shipping),
     true
show 'Shipping::Rate reloaded in the Main Box',
     Shipping::Rate::LOADED_IN.equal?(main_box),
     false
show 'Shipping::Carriers reloaded from its nsfile',
     !Shipping::Carriers.equal?(old_carriers) &&
       !Shipping::Carriers::LOADED_IN.equal?(main_box),
     true
show 'Shipping::Rate is still the held class',
     Shipping::Rate.equal?(held_rate_class),
     false
# The held class is the old one: it still runs the code it was loaded with.
show 'held class still answers', held_rate_class.quote(1), 700
show 'an older instance is a Shipping::Rate',
     old_rate.is_a?(Shipping::Rate),
     false
