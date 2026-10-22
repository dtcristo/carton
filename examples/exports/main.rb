# frozen_string_literal: true

require_relative '../../lib/carton'

# Each Entrypoint runs in its own Carton Box and explicitly exports a value.
settings = import_relative 'settings'
money = import_relative 'formatter'
legacy = import_relative 'legacy_adapter'

# Hash Exports use Ruby's own pattern matching, including Method values.
settings => { currency: }
legacy => { label:, prefix: }
puts "#{label.call(42)}: #{currency} #{money.call(4_200)}"
puts "Captured method: #{label.call(7)}"
puts "Legacy prefix: #{prefix}"
puts "PREFIX defined in Main: #{!defined?(PREFIX).nil?}"
