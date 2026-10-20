# frozen_string_literal: true

require_relative 'assertions'
gems = Ruby::Box.new
gems.eval <<~CODE
  module SharedDependency
    MARKER = 'from-gems'
  end
  class String
    def shared_probe(prefix = '', suffix:, &block)
      [prefix + SharedDependency::MARKER + upcase + suffix, block.call, Ruby::Box.current]
    end
    alias shared_alias shared_probe
    protected def shared_protected = :protected
    private def shared_private = :private
    def shared_failure = raise(ArgumentError, 'shared failure')
    def shared_chain = shared_private
    def upcase = 'replacement'
    def self.shared_singleton = Ruby::Box.current
  end
  captured = 'closure'
  String.define_method(:shared_closure) { captured }
CODE
install =
  lambda do |box|
    methods = gems.eval(<<~CODE)
      String.instance_methods(false).grep(/^shared_/).to_h do |name|
        [name, String.instance_method(name)]
      end.merge(upcase: String.instance_method(:upcase), shared_private: String.instance_method(:shared_private))
    CODE
    box.eval(<<~CODE).call(methods)
    ->(methods) do
      methods.each { |name, method| String.define_method(name, method) }
      String.send(:protected, :shared_protected)
      String.send(:private, :shared_private)
    end
  CODE
    singleton =
      gems.eval('String.singleton_class.instance_method(:shared_singleton)')
    box.eval(
      '->(m) { String.singleton_class.define_method(:shared_singleton, m) }',
    ).call(singleton)
  end
billing = Ruby::Box.new
shipping = Ruby::Box.new
[billing, shipping].each do |box|
  install.call(box)
  result = box.eval('"hello".shared_probe("p:", suffix: "!") { :block }')
  equal(['p:from-gemsreplacement!', :block, gems], result)
  equal(gems, box.eval('String.shared_singleton'))
  equal('closure', box.eval('"".shared_closure'))
  equal(:private, box.eval('"".shared_chain'))
  equal(
    true,
    box.eval(
      'String.protected_instance_methods(false).include?(:shared_protected)',
    ),
  )
  equal(
    true,
    box.eval(
      'String.private_instance_methods(false).include?(:shared_private)',
    ),
  )
  equal(
    gems.eval('String.instance_method(:shared_alias)'),
    box.eval('String.instance_method(:shared_alias)'),
  )
  equal(String, box.eval('String.instance_method(:shared_probe).owner'))
  equal(gems, box.eval('"".method(:shared_probe).box'))
  equal(gems, box.eval('String.method(:shared_singleton).box'))
  error =
    box.eval(
      'begin; "".shared_failure; rescue ArgumentError => e; [e.message, e.backtrace.first]; end',
    )
  equal('shared failure', error.first)
  assert(error.last.include?('shared_failure'))
end
threads =
  8.times.map do
    Thread.new do
      100.times do
        equal(gems, shipping.eval('"".shared_probe(suffix: "") { nil }.last'))
      end
    end
  end
threads.each(&:value)
billing.eval('class String; def shared_probe(*) = :billing; end')
equal(:billing, billing.eval('"".shared_probe'))
equal(gems, shipping.eval('"".shared_probe(suffix: "") { nil }.last'))
equal(gems, gems.eval('"".shared_probe(suffix: "") { nil }.last'))
equal(false, ''.respond_to?(:shared_probe))
equal(false, Ruby::Box.master.eval('String.method_defined?(:shared_probe)'))
# Ordinary singleton owners cannot be rebound onto an unrelated class.
gems.eval('class SingletonOwner; def self.probe = 1; end')
singleton = gems.eval('SingletonOwner.singleton_class.instance_method(:probe)')
error =
  begin
    shipping.eval(
      '->(m) { Class.new.singleton_class.define_method(:probe, m) }',
    ).call(singleton)
    nil
  rescue TypeError => e
    e
  end
assert(error&.message&.include?("can't bind singleton method"))
puts 'PASS transplantation, context, visibility, arguments, closures, singleton, exceptions, threads, overrides'
