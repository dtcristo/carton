# frozen_string_literal: true

require_relative '../../lib/carton'

Carton.setup_bundle

# UNSUPPORTED HACK: Ruby's docs say no code runs in the Master Box, the copy
# source for every new Box. On Ruby 4.0.7, code required there anyway is
# inherited by Boxes created afterwards, so a prelude loads once instead of
# once per Carton. Do this before the first import.
def load_master_prelude(path)
  master = Ruby::Box.master
  # The prelude's code runs in Master even when a Carton calls it, so lazy
  # requires (I18n loads its backend on first use) search Master's load path.
  # The gem paths must stay; every Box created afterwards inherits them.
  master.load_path.unshift(
    *Gem.loaded_specs.values.flat_map(&:full_require_paths),
  )
  master.require(path)
end

started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
load_master_prelude(File.expand_path('prelude.rb', __dir__))
loaded = Process.clock_gettime(Process::CLOCK_MONOTONIC)

# Each Carton still runs in its own Box, but starts with Active Support.
Pricing = import_relative 'cartons/pricing'
Reports = import_relative 'cartons/reports'
imported = Process.clock_gettime(Process::CLOCK_MONOTONIC)

# Print each result and fail if it is not what Active Support would return.
def show(label, value, expected)
  puts "#{label} = #{value}"
  abort "expected #{expected.inspect}" unless value == expected
end

puts '-- Cartons using Active Support from the prelude --'
show "Pricing.label('')", Pricing.label(''), 'unnamed plan'
show 'Pricing.trial_ends(2026-01-01)',
     Pricing.trial_ends(Time.utc(2026, 1, 1)),
     Time.utc(2026, 1, 15)
show 'Reports.summary(%w[a b c])', Reports.summary(%w[a b c]), 'a, b, and c'
show 'Reports.summary([])', Reports.summary([]), 'nothing to report'
puts
puts '-- Cost --'
puts format(
       'prelude loaded into Master once: %.0fms',
       (loaded - started) * 1000,
     )
puts format('both Cartons imported: %.0fms', (imported - loaded) * 1000)
puts
puts '-- The prelude can reach Main --'
# Main sees a Master patch to a builtin class only until Ruby copies that
# class's state for Main, which method calls as well as changes can trigger,
# so which patches show up here is not guaranteed.
puts "Main sees ''.blank?: #{''.respond_to?(:blank?)}"
puts "Main sees 1.day: #{1.respond_to?(:day)}"
