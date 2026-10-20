# frozen_string_literal: true

require_relative 'shared_gems_prototype'
require 'tmpdir'
shared = SharedGemsPrototype.new(gemfile: File.expand_path('Gemfile', __dir__))
shared.load('zeitwerk', 'json')
child = shared.create_box
equal({ 'ok' => true }, child.eval('JSON.parse(%q({"ok":true}))'))
equal(
  '8.1.4',
  shared.box.eval('Gem.loaded_specs.fetch("activesupport").version.to_s'),
)
equal(false, child.eval('Gem.loaded_specs.key?("activesupport")'))
# Bundle restrictions do not follow constant/method installation.
equal(
  'Gem::LoadError',
  shared.box.eval(
    'begin; gem "rake"; rescue Exception => e; e.class.name; end',
  ),
)
assert(child.eval('gem "rake"; Gem.loaded_specs.key?("rake")'))
Dir.mktmpdir('shared-gems-zeitwerk') do |dir|
  File.write(File.join(dir, 'shared_widget.rb'), 'class SharedWidget; end')
  loader =
    child.eval(
      "Zeitwerk::Loader.new.tap { |l| l.push_dir(#{dir.inspect}); l.setup; l.eager_load }",
    )
  assert(loader.is_a?(shared.box.const_get(:Zeitwerk).const_get(:Loader)))
  equal(true, shared.box.eval('Object.const_defined?(:SharedWidget, false)'))
  equal(false, child.eval('Object.const_defined?(:SharedWidget, false)'))
end
# Existing independent version selection remains available outside the hook.
independent = Ruby::Box.new
independent.eval('gem "activesupport", "8.1.2"; require "active_support"')
equal('8.1.2', independent.eval('ActiveSupport::VERSION::STRING'))
puts 'PASS shared native JSON and independent version selection outside sharing'
puts 'VERIFIED LIMIT bundle activation/restrictions are absent in children'
puts 'VERIFIED LIMIT shared Zeitwerk loader defines application classes in Gems by default'
