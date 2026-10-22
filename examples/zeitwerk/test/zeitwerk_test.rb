# frozen_string_literal: true

require_relative '../../../lib/carton'

# Bundle boundary: the app's Gemfile, with its test group.
Carton.setup_bundle(:default, :test)
require 'minitest/autorun'
require 'zeitwerk'

# The app's loader ignores the shipping Carton, as main.rb's does.
LIB = File.expand_path('../lib', __dir__)
APP_LOADER = Zeitwerk::Loader.new
APP_LOADER.push_dir(LIB)
APP_LOADER.ignore(File.join(LIB, 'shipping.rb'), File.join(LIB, 'shipping'))
APP_LOADER.setup

# Checked before the imports below replace the constant.
SHIPPING_AUTOLOAD = Object.autoload?(:Shipping)

# Carton boundary: each Carton runs its own Zeitwerk loader in its own Box.
Billing = import_relative '../cartons/billing'
Shipping = import_relative '../lib/shipping'

# Carriers is not eager loaded, so until first referenced its autoload points
# at its nsfile. Checked here, since the reload test references it.
CARRIERS_AUTOLOAD = Shipping.autoload?(:Carriers)

class ZeitwerkTest < Minitest::Test
  ROOT = File.expand_path('..', __dir__)

  def test_app_loader_ignores_the_shipping_carton
    assert_nil SHIPPING_AUTOLOAD
  end

  def test_each_box_has_its_own_zeitwerk
    assert_equal '2.8.3', Zeitwerk::VERSION
    assert_equal '2.7.5', Billing.zeitwerk_version
    assert_equal %w[lib], relative(Zeitwerk::Loader.all_dirs)
    assert_equal %w[cartons/billing/lib], relative(Billing.zeitwerk_dirs)
    assert_equal %w[lib/shipping], relative(Shipping.zeitwerk_dirs)
    # nsfiles arrived in Zeitwerk 2.8, so only the shipping Box has them.
    refute Billing.zeitwerk_nsfiles?
    assert Shipping.zeitwerk_nsfiles?
  end

  def test_eager_loading_runs_in_the_carton_box
    APP_LOADER.eager_load
    assert_empty $LOADED_FEATURES.grep(%r{/(billing|shipping)(/|\.rb)})
    refute_in_main Shipping::Rate
  end

  def test_lazy_autoload_runs_in_the_carton_box
    # Archive is not eager loaded, so this reference triggers its autoload
    # from the Main Box. archive.rb still runs in billing's Box.
    refute_in_main Billing::Archive
  end

  def test_lazy_nsfile_namespace_runs_in_the_carton_box
    assert_equal 'lib/shipping/carriers/ns.rb',
                 relative([CARRIERS_AUTOLOAD]).first
    refute_in_main Shipping::Carriers
    refute_in_main Shipping::Carriers::Post
    refute Shipping::Carriers.const_defined?(:Ns, false)
  end

  def test_app_code_calls_both_cartons
    assert_equal 'invoice $42.00 + shipping $11.00', OrderSummary.line(4200, 3)
  end

  def test_reload_replaces_classes_but_not_held_references
    held_rate_class = Shipping::Rate
    old_rate = Shipping::Rate.new
    old_carriers = Shipping::Carriers
    Shipping.reload!

    assert_same Shipping, import_relative('../lib/shipping')
    refute_in_main Shipping::Rate
    refute_same held_rate_class, Shipping::Rate
    # The held class still runs the code it was loaded with.
    assert_equal 700, held_rate_class.quote(1)
    refute_kind_of Shipping::Rate, old_rate
    # The nsfile runs again, in the Carton Box, for a new namespace.
    refute_same old_carriers, Shipping::Carriers
    refute_in_main Shipping::Carriers
  end

  private

  def relative(dirs) = dirs.map { it.delete_prefix("#{ROOT}/") }

  # Each probed Interior file records the Box that ran it.
  def refute_in_main(constant)
    refute_same Ruby::Box.main, constant::LOADED_IN
  end
end
