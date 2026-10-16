# frozen_string_literal: true

# The Carton's Entrypoint, running in its own Box. Zeitwerk autoloads
# Billing::Invoice here, independently of the Rails app's loader in Main.
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

# Only Billing crosses the Carton boundary.
export_default Billing
