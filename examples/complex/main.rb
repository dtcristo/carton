# frozen_string_literal: true

require_relative '../../lib/package'

packages_dir = File.expand_path('packages', __dir__)

# Local package lib directories still need to be on the caller's load path when
# we want import 'name' to resolve inside nested boxes.
Dir
  .glob(File.join(packages_dir, '*/lib'))
  .sort
  .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }

adventure_entry =
  File.expand_path('packages/adventure/lib/adventure.rb', __dir__)
adventure_gemfile = File.expand_path('packages/adventure/Gemfile', __dir__)
loot_entry = File.expand_path('packages/loot/lib/loot.rb', __dir__)

# Bundler still picks the active Gemfile from env/process state today, so the
# bundled import stays explicit even though the wrapper is small.
Adventure = Package.with_bundle(adventure_gemfile) { import adventure_entry }

Plans = import 'quest'
summary, challenge_summary = Plans.fetch_values :summary, :challenge_summary

# loot keeps dotenv loading in a subprocess because switching from one active
# bundle to another conflicting one is not reliable in a single process yet.
import(loot_entry) => { legacy_message:, DOTENV_VERSION: loot_dotenv_version }

puts '-- bundled single export --'
puts "Adventure.banner = #{Adventure.banner}"
puts "Adventure.dotenv_version = #{Adventure.dotenv_version}"
puts
puts '-- named export loaded by name --'
puts "Plans::FEATURES = #{Plans::FEATURES.join(', ')}"
puts "Plans.summary = #{summary}"
puts "Plans.challenge_summary = #{challenge_summary}"
puts
puts '-- destructured named export --'
puts "loot dotenv version = #{loot_dotenv_version}"
puts "legacy_message = #{legacy_message}"
