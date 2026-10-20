# frozen_string_literal: true

require_relative 'assertions'
gems = Ruby::Box.new
gems.eval <<~CODE
  module Dependency
    class Base
      def origin = Ruby::Box.current
    end
    STATE = []
    def self.state = STATE
  end
CODE
billing, shipping = Array.new(2) { Ruby::Box.new }
[billing, shipping].each do |box|
  box.const_set(:Dependency, gems.const_get(:Dependency, false))
  box.eval(
    'class Invoice < Dependency::Base; def application_origin = Ruby::Box.current; end',
  )
  equal(gems, box.eval('Invoice.new.origin'))
  equal(box, box.eval('Invoice.new.application_origin'))
end
assert(!billing.const_get(:Invoice).equal?(shipping.const_get(:Invoice)))
billing.eval(
  'Dependency::STATE << :billing; class Dependency::Base; def reopened = :shared; end',
)
equal([:billing], shipping.eval('Dependency.state'))
equal(:shared, shipping.eval('Invoice.new.reopened'))
equal(false, Object.const_defined?(:Dependency))
puts 'PASS constant bindings, inheritance and local application classes; dependency mutation intentionally shared'
