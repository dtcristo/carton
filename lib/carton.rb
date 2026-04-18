# frozen_string_literal: true

raise 'Ruby 4.0+ is required for Carton' if RUBY_VERSION.to_f < 4.0

module Carton
  module_function
end

require_relative 'carton/bundle'
require_relative 'carton/export_methods'
require_relative 'carton/exports'
require_relative 'carton/box'
require_relative 'carton/runtime'
require_relative 'carton/kernel_patch'

module Carton
  private_constant :ExportMethods
  private_constant :Runtime
  private_constant :KernelPatch
  private_constant :BoxedRubyGems
end
