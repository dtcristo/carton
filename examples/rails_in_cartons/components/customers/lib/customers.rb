# frozen_string_literal: true

require 'carton'
require 'zeitwerk'
require 'active_support/core_ext/object/blank'

module Customers
  Framework = import 'framework'
  private_constant :Framework

  # This Box's Zeitwerk owns the Engine's Ruby code, including lazy autoloads.
  LOADER = Zeitwerk::Loader.new
  %w[models controllers jobs].each do |directory|
    path = File.expand_path("../app/#{directory}", __dir__)
    LOADER.push_dir(path) if Dir.exist?(path)
  end
  LOADER.setup
  private_constant :LOADER
end

require_relative 'customers/engine'

export Customers
