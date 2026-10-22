# frozen_string_literal: true

require_relative '../../lib/carton'

# A month-end report runner. It has no Gemfile and never loads Faraday; each
# plugin brings its own bundle.

# The orders are frozen because objects are shared across Boxes: a plugin
# could otherwise change them for the host and every other plugin.
ORDERS = [
  { month: '2026-06', state: 'CA', amount: 600.0 },
  { month: '2026-06', state: 'NY', amount: 400.0 },
  { month: '2026-07', state: 'CA', amount: 630.5 },
  { month: '2026-07', state: 'TX', amount: 449.5 },
  { month: '2026-08', state: 'NY', amount: 550.25 },
  { month: '2026-08', state: 'TX', amount: 699.75 },
  { month: '2026-09', state: 'CA', amount: 981.0 },
  { month: '2026-09', state: 'NY', amount: 350.0 },
].map(&:freeze).freeze

# The plugin interface. A plugin is a directory, plugins/<name>/, whose
# Entrypoint lib/<name>.rb exports a module with `title` and `call(orders)`,
# which sends the orders somewhere and returns report lines as Strings.
PLUGIN_METHODS = %i[title call].freeze

plugin_dirs = Dir.glob('plugins/*/', base: __dir__).sort

plugins =
  plugin_dirs.map do |dir|
    # Carton boundary: each import loads one plugin, and its gems, in a new
    # Box. Only its Export comes back. The path is found at runtime, so mark
    # it for `carton check`.
    plugin = import_relative dir # carton:dynamic

    missing = PLUGIN_METHODS.reject { plugin.respond_to?(it) }
    raise "#{dir} lacks #{missing.join(', ')}" if missing.any?

    plugin
  end

plugins.each do |plugin|
  puts "== #{plugin.title} =="
  puts plugin.call(ORDERS)
  puts
end

# Neither plugin's gems nor crm's Float#to_s patch reached the host.
puts '== Host =='
puts "Faraday defined: #{!defined?(Faraday).nil?}"
puts "0.1 + 0.2 = #{0.1 + 0.2}"
