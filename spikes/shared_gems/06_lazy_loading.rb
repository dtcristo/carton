# frozen_string_literal: true

require_relative 'shared_gems_prototype'
require 'tmpdir'
def features(box)
  box.eval("load #{File.expand_path('fixtures/observe.rb', __dir__).inspect}")
  box.instance_variable_get(:@spike_features)
end
shared = SharedGemsPrototype.new
shared.load(File.expand_path('fixtures/lazy.rb', __dir__))
child = shared.create_box
# Shared module autoload resolves to the defining Box.
equal(shared.box, child.eval('LazyDependency::Loaded::BOX'))
Dir.mktmpdir('shared-gems-lazy') do |dir|
  direct = File.join(dir, 'direct.rb')
  nested = File.join(dir, 'nested.rb')
  File.write(direct, 'DIRECT_BOX = Ruby::Box.current')
  File.write(nested, 'NESTED_BOX = Ruby::Box.current')
  equal(shared.box, child.eval("''.shared_lazy(#{direct.inspect})"))
  # Direct call from eval loads in Gems.
  equal(shared.box, shared.box.const_get(:DIRECT_BOX))
  child.const_set(:LAZY_PATH, nested)
  child.require(File.expand_path('fixtures/call_lazy.rb', __dir__))
  # A require inside the transplanted Ruby method stays in Gems here.
  equal(shared.box, child.const_get(:LAZY_RESULT))
  equal(shared.box, shared.box.const_get(:NESTED_BOX))
  assert(features(shared.box).include?(direct))
  assert(features(shared.box).include?(nested))
  equal(false, features(child).include?(direct))
end
# With an ordinary local require there is no deduplication contract.
shared = SharedGemsPrototype.new(gemfile: File.expand_path('Gemfile', __dir__))
shared.load('active_support', 'active_support/core_ext/object/blank')
child = shared.create_box
before = child.eval('"".method(:blank?).box')
# Nonshared dependencies still load independently before the failed reload.
child.eval('require "set"')
equal(true, child.eval('Set.new([1, 1]).size == 1'))
error =
  begin
    child.eval('require "active_support/core_ext/object/blank"')
    nil
  rescue StandardError, LoadError => e
    e
  end
assert(error, 'Expected the observed duplicate-loading failure')
equal(shared.box, before)
puts "VERIFIED FAILURE local require after sharing raises #{error.class}: #{error.message.lines.first.strip}"
puts 'PASS shared autoload, lazy requires, loading-frame provenance and nonshared dependency loading'
puts 'LIMIT local require reopens shared concurrent-ruby classes and leaves partial initialization'
puts 'PASS lazy require from the shared method during child.require stays in Gems'
