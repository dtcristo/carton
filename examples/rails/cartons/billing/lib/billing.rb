# frozen_string_literal: true

require 'carton'
require 'zeitwerk'

module Billing
  # Carton boundary: Rails comes from the framework Carton's Export.
  Framework = import 'framework'
  private_constant :Framework
  Customers = import 'customers'
  private_constant :Customers

  # This Box's Zeitwerk owns the Engine's Ruby code, including lazy autoloads.
  # Each Engine repeats this setup: a shared Framework helper would run
  # Zeitwerk in Framework's Box instead of this one.
  LOADER = Zeitwerk::Loader.new
  %w[models controllers repositories].each do |directory|
    LOADER.push_dir(File.expand_path("../app/#{directory}", __dir__))
  end
  LOADER.push_dir(File.expand_path('billing', __dir__), namespace: Billing)
  LOADER.ignore(File.expand_path('billing/engine.rb', __dir__))
  LOADER.setup
  private_constant :LOADER, :TaxPolicy
end

require_relative 'billing/engine'

# Export: the Engine's namespace.
export Billing
