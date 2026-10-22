# frozen_string_literal: true

require 'carton'
require 'zeitwerk'

module Billing
  Framework = import 'framework'
  private_constant :Framework
  Customers = import 'customers'
  private_constant :Customers

  # This Box's Zeitwerk owns the Engine's Ruby code, including lazy autoloads.
  LOADER = Zeitwerk::Loader.new
  %w[models controllers repositories].each do |directory|
    path = File.expand_path("../app/#{directory}", __dir__)
    LOADER.push_dir(path) if Dir.exist?(path)
  end
  LOADER.push_dir(File.expand_path('billing', __dir__), namespace: Billing)
  LOADER.ignore(File.expand_path('billing/engine.rb', __dir__))
  LOADER.setup
  private_constant :LOADER, :TaxPolicy
end

require_relative 'billing/engine'

export Billing
