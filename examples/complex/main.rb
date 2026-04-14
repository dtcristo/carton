# frozen_string_literal: true

require_relative '../../lib/package'

packages_dir = File.expand_path('packages', __dir__)
Dir
  .glob(File.join(packages_dir, '*/lib'))
  .sort
  .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }

adventure_entry =
  File.expand_path('packages/adventure/lib/adventure.rb', __dir__)
adventure_gemfile = File.expand_path('packages/adventure/Gemfile', __dir__)
loot_entry = File.expand_path('packages/loot/lib/loot.rb', __dir__)

previous_gemfile = ENV['BUNDLE_GEMFILE']
ENV['BUNDLE_GEMFILE'] = adventure_gemfile
Adventure = import adventure_entry
if previous_gemfile
  ENV['BUNDLE_GEMFILE'] = previous_gemfile
else
  ENV.delete 'BUNDLE_GEMFILE'
end

Plans = import 'quest'
summary, challenge_summary = Plans.fetch_values :summary, :challenge_summary
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
