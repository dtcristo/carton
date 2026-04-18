# frozen_string_literal: true

require_relative '../../lib/carton'

cartons_dir = File.expand_path('cartons', __dir__)

# Name-based imports stay explicit: the caller chooses which carton lib
# directories are available here.
Dir
  .glob(File.join(cartons_dir, '*/lib'))
  .sort
  .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }

Adventure = import 'adventure'
Plans = import 'quest'
import('loot') => { legacy_message:, DOTENV_VERSION: loot_dotenv_version }

puts '-- Bundled single export --'
puts "Adventure.banner = #{Adventure.banner}"
puts "Adventure.dotenv_version = #{Adventure.dotenv_version}"
puts
puts '-- Named export loaded by name --'
puts "Plans::FEATURES = #{Plans::FEATURES.join(', ')}"
puts "Plans.summary = #{Plans.fetch :summary}"
puts
puts '-- Destructured named export --'
puts "loot dotenv version = #{loot_dotenv_version}"
puts "legacy_message = #{legacy_message}"

STDOUT.flush
Process.exit!(0)
