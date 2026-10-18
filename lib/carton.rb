# frozen_string_literal: true

require_relative 'carton/error'
require_relative 'carton/bundler'
require_relative 'carton/namespace_methods'
require_relative 'carton/namespace'
require_relative 'carton/box'
require_relative 'carton/gem_activation'
require_relative 'carton/import_cache'
require_relative 'carton/resolver'
require_relative 'carton/runtime'
require_relative 'carton/kernel_patch'

module Carton
  private_constant :Box
  private_constant :GemActivation
  private_constant :ImportCache
  private_constant :KernelPatch
  private_constant :NamespaceMethods
  private_constant :Resolver
  private_constant :Runtime
end
