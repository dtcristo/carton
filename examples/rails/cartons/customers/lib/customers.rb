# frozen_string_literal: true

require 'carton'
require 'zeitwerk'

module Customers
  Framework = import 'framework'
  private_constant :Framework

  # This Box's Zeitwerk owns the Engine's Ruby code, including lazy autoloads.
  # Each Engine repeats this setup: a shared Framework helper would run
  # Zeitwerk in Framework's Box instead of this one.
  LOADER = Zeitwerk::Loader.new
  %w[models controllers repositories].each do |directory|
    LOADER.push_dir(File.expand_path("../app/#{directory}", __dir__))
  end
  LOADER.push_dir(File.expand_path('customers', __dir__), namespace: Customers)
  LOADER.ignore(File.expand_path('customers/engine.rb', __dir__))
  LOADER.setup
  private_constant :LOADER
end

require_relative 'customers/engine'

export Customers
