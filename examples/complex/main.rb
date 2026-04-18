# frozen_string_literal: true

require_relative '../../lib/carton'

cartons_dir = File.expand_path('cartons', __dir__)

# Local carton lib directories still need to be on the caller's load path when
# we want import 'name' to resolve inside nested boxes.
Dir
  .glob(File.join(cartons_dir, '*/lib'))
  .sort
  .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }

Adventure = import 'adventure'
Plans = import 'quest'

# loot still imports by name, but it does not need Carton.with_bundle here
# because the conflicting dotenv activation happens entirely in the subprocess
# inside loot.rb, not during this import itself.
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
