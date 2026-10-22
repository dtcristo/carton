# frozen_string_literal: true

require 'carton'

# Actions render JSON with to_json.
require 'json'

module Billing
  Framework = import 'framework'
  Hanami = Framework::Hanami
  Dry = Framework::Dry

  private_constant :Framework, :Hanami, :Dry
end

require_relative 'billing/config/slice'
require 'zeitwerk'

loader = Zeitwerk::Loader.new
loader.push_dir(File.expand_path('billing', __dir__), namespace: Billing)
loader.inflector.inflect('db' => 'DB')
loader.ignore(
  File.expand_path('billing/config', __dir__),
  File.expand_path('billing/templates', __dir__),
)
loader.setup

# Hanami keeps its container and conventions; this loader owns source evaluation.
Billing::Slice.autoloader.ignore(File.expand_path('billing', __dir__))
Billing.private_constant :TaxPolicy

export Billing
