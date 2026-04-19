# frozen_string_literal: true

raise 'Ruby 4.0+ is required for Carton' if RUBY_VERSION.to_f < 4.0

require_relative 'carton/bundler'
require_relative 'carton/export_methods'
require_relative 'carton/exports'
require_relative 'carton/box'
require_relative 'carton/runtime'
require_relative 'carton/kernel_patch'
require_relative 'carton/rubygems'

module Carton
  private_constant :BoxedRubyGems
  private_constant :ExportMethods
  private_constant :KernelPatch
  private_constant :Runtime
end
