# frozen_string_literal: true

require 'carton'
require 'zeitwerk'

module Orders
  Framework = import 'framework'
  private_constant :Framework
  Customers = import 'customers'
  private_constant :Customers

  # This Box's Zeitwerk owns the Engine's Ruby code, including lazy autoloads.
  LOADER = Zeitwerk::Loader.new
  %w[models controllers jobs].each do |directory|
    path = File.expand_path("../app/#{directory}", __dir__)
    LOADER.push_dir(path) if Dir.exist?(path)
  end
  LOADER.setup
  private_constant :LOADER
end

require_relative 'orders/engine'

export Orders
