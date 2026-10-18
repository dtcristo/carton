# frozen_string_literal: true

require_relative '../../lib/carton'

# Carton boundaries: each file runs in its own Box. Its import returns a
# Hash, a Proc, or a Namespace for a file without export, respectively.
settings = import_relative 'settings'
money = import_relative 'formatter'
Legacy = import_relative 'legacy'

# A Hash export uses Ruby's own pattern matching.
settings => { currency: }
puts "#{Legacy.label(42)}: #{currency} #{money.call(4_200)}"

# A Bare Carton supports pattern matching too. A helper is a Method value;
# extracting it does not call it.
Legacy => { label: }
puts "Captured helper: #{label.call(7)}"
puts "Legacy prefix: #{Legacy::PREFIX}"
puts "PREFIX defined in Main: #{!defined?(PREFIX).nil?}"
