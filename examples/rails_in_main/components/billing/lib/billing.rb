# frozen_string_literal: true

# The Carton's Entrypoint, running in its own Box. This Box's own Zeitwerk
# loader manages lib/billing/, independently of the Rails app's loader in Main.
require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.setup

module Billing
  # Internal to the Carton: importers get NameError for Billing::TaxPolicy.
  module TaxPolicy
    def self.tax_cents(subtotal_cents) = (subtotal_cents * 0.1).round
  end
  private_constant :TaxPolicy

  # Rails' core extensions (`blank?`, `present?`, ...) are monkey patches in
  # the Main Box, so they are not visible inside this Box.
  def self.active_support_visible? = ''.respond_to?(:blank?)
end

# Load lib/billing/ now, as Rails does in production, so a broken file fails
# at boot. Left to autoload, Billing::Invoice would still load in this Box
# when InvoicesController first references it.
loader.eager_load

# Only Billing crosses the Carton boundary.
export_default Billing
