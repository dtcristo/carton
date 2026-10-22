# frozen_string_literal: true

# The shipping Carton's Entrypoint. It sits in the app's lib/, which the app's
# own Zeitwerk loader manages in the Main Box, so main.rb tells that loader to
# ignore this file and lib/shipping/. Everything here runs in the shipping
# Carton's own Box.

# Bundle boundary: the app's Gemfile, found by searching upward, set up again
# in this Box. This
# Box gets its own copy of zeitwerk 2.8.3, separate from the app's.
Carton.setup_bundle
require 'zeitwerk'

# The Entrypoint defines the root namespace, and the loader manages only
# lib/shipping/ inside it. Reloading then replaces Shipping::Rate but never
# Shipping itself, the module importers hold.
module Shipping
  # This Box's Zeitwerk, not the app's.
  def self.zeitwerk_dirs = Zeitwerk::Loader.all_dirs
  def self.zeitwerk_nsfiles? = Zeitwerk::Loader.method_defined?(:nsfile=)
end

loader = Zeitwerk::Loader.new
# Zeitwerk 2.8+: a directory's ns.rb defines its namespace, so
# shipping/carriers/ns.rb defines Shipping::Carriers.
loader.nsfile = 'ns.rb'
loader.push_dir(File.join(__dir__, 'shipping'), namespace: Shipping)
# Carriers stays lazy, so its autoload, which points at its ns.rb, is
# triggered from the Main Box; see this example's guide on the website.
loader.do_not_eager_load(File.join(__dir__, 'shipping', 'carriers'))
loader.enable_reloading
loader.setup
loader.eager_load

# Reloads in this Box: the block was defined here, so it runs here even when
# the app calls it.
Shipping.define_singleton_method(:reload!) do
  loader.reload
  loader.eager_load
end

# Export: only Shipping crosses the Carton boundary.
export Shipping
