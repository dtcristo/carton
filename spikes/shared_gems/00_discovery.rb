# frozen_string_literal: true

require_relative 'shared_gems_prototype'
shared = SharedGemsPrototype.new
shared.box.eval <<~CODE
  class Object
    def shared_remove = :ancestor
    def shared_hide = :inherited
  end
  class String
    def shared_remove = :before
    def shared_visibility = :before
  end
CODE
# Capture a known baseline so removal and undef can both be tested.
shared.instance_variable_set(:@before, shared.send(:snapshot))
shared.box.eval <<~CODE
  class String
    remove_method :shared_remove
    undef_method :shared_hide
    def shared_added = Ruby::Box.current
    alias shared_alias shared_added
    protected :shared_visibility
    private def shared_secret = :secret
    def self.shared_class = Ruby::Box.current
    SPIKE_CONSTANT = :unsupported
    @spike_ivar = :unsupported
    @@spike_cvar = :unsupported
  end
CODE
shared.capture
child = Ruby::Box.new
child.eval <<~CODE
  class Object
    def shared_remove = :ancestor
    def shared_hide = :inherited
  end
  class String
    def shared_remove = :before
    def shared_visibility = :before
  end
CODE
shared.install(child)
equal(shared.box, child.eval('"".shared_added'))
equal(shared.box, child.eval('String.shared_class'))
equal(
  false,
  child.eval('String.instance_methods(false).include?(:shared_remove)'),
)
equal(:ancestor, child.eval('"".shared_remove'))
equal(false, child.eval('String.method_defined?(:shared_hide)'))
equal(true, child.eval('String.protected_method_defined?(:shared_visibility)'))
equal(true, child.eval('String.private_method_defined?(:shared_secret)'))
equal(
  shared.box.eval('String.instance_method(:shared_added)'),
  child.eval('String.instance_method(:shared_alias)'),
)
entry = shared.manifest.find { |e| e[:name] == 'String' && !e[:singleton] }
equal(%i[constants ivars cvars], entry[:unsupported])
equal(false, child.eval('String.const_defined?(:SPIKE_CONSTANT, false)'))
# Same names, different implementations must still produce a delta.
shared.box.eval('class String; def upcase = :replacement; end')
shared.capture
assert(
  shared
    .manifest
    .find { |e| e[:name] == 'String' && !e[:singleton] }
    .fetch(:methods)
    .key?(:upcase),
)
puts 'PASS discovery of addition, replacement, removal, undef, aliases, visibility and singleton methods'
puts 'LIMIT constants, ivars and cvars are reported but not replayed'

# Public reflection cannot distinguish removal from undef when neither exposes
# an inherited fallback. Refuse that delta instead of inventing its semantics.
ambiguous = SharedGemsPrototype.new
ambiguous.box.eval('class String; def shared_missing = :before; end')
ambiguous.instance_variable_set(:@before, ambiguous.send(:snapshot))
ambiguous.box.eval('class String; remove_method :shared_missing; end')
ambiguous.capture
error =
  begin
    ambiguous.create_box
    nil
  rescue RuntimeError => e
    e
  end
assert(error&.message&.include?('Cannot distinguish removal from undef'))
puts 'VERIFIED LIMIT missing direct method without inherited fallback is ambiguous and refused'
