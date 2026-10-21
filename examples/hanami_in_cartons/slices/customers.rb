# frozen_string_literal: true

require 'carton'
Carton.setup_bundle
require 'json'
module Customers
  Framework = import_relative '../lib/framework'
  Hanami = Framework::Hanami
  Dry = Framework::Dry
  private_constant :Framework, :Hanami, :Dry
end
require_relative 'customers/config/slice'
require 'zeitwerk'
loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path('customers', __dir__), namespace: Customers)
loader.inflector.inflect('db' => 'DB')
loader.ignore(
  File.expand_path('customers/config', __dir__),
  File.expand_path('customers/templates', __dir__),
)
loader.setup
# Hanami keeps its container and conventions; this loader owns source evaluation.
Customers::Slice.autoloader.ignore(File.expand_path('customers', __dir__))
export Customers
