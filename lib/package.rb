# frozen_string_literal: true

raise 'Ruby 4.0+ is required for Package' if RUBY_VERSION.to_f < 4.0

module Package
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

require_relative 'package/export_methods'
require_relative 'package/exports'
require_relative 'package/box'
require_relative 'package/runtime'
require_relative 'package/kernel_patch'

module Package
  private_constant :ExportMethods
  private_constant :Runtime
  private_constant :KernelPatch
end
