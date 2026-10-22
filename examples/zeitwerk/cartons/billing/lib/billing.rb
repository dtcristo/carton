# frozen_string_literal: true

# The billing Carton's Entrypoint. Everything in this file and lib/billing/
# runs in the billing Carton's own Box.

# Bundle boundary: cartons/billing/Gemfile locks zeitwerk 2.7.5, while
# the app locks 2.8.3. Each Box requires its own copy of Zeitwerk.
Carton.setup_bundle
require 'zeitwerk'

# A Carton already has Zeitwerk's gem layout (lib/billing.rb plus
# lib/billing/), so for_gem needs no configuration.
loader = Zeitwerk::Loader.for_gem
# Archive stays lazy to show that an autoload triggered from another Box still
# runs here; see this example's guide on the website.
loader.do_not_eager_load(File.join(__dir__, 'billing', 'archive.rb'))
loader.setup

module Billing
  def self.invoice(cents) = Invoice.new(cents).to_s

  # This Box's Zeitwerk, not the app's.
  def self.zeitwerk_version = Zeitwerk::VERSION
  def self.zeitwerk_dirs = Zeitwerk::Loader.all_dirs
  def self.zeitwerk_nsfiles? = Zeitwerk::Loader.method_defined?(:nsfile=)
end

# Load the rest of the Carton now, as an app does in production, so a broken
# file fails at boot. Lazy autoloads would also run in this Box.
loader.eager_load

# Export: only Billing crosses the Carton boundary.
export Billing
