# frozen_string_literal: true

raise 'Ruby 4.0+ is required for Carton' if RUBY_VERSION.to_f < 4.0

module Carton
  module_function

  def with_bundle(gemfile)
    previous = ENV['BUNDLE_GEMFILE']
    ENV['BUNDLE_GEMFILE'] = gemfile
    yield
  ensure
    if previous
      ENV['BUNDLE_GEMFILE'] = previous
    else
      ENV.delete 'BUNDLE_GEMFILE'
    end
  end
end

require_relative 'carton/export_methods'
require_relative 'carton/exports'
require_relative 'carton/box'
require_relative 'carton/runtime'
require_relative 'carton/kernel_patch'

module Carton
  private_constant :ExportMethods
  private_constant :Runtime
  private_constant :KernelPatch
end
