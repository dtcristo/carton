# frozen_string_literal: true

require_relative 'assertions'
gems = Ruby::Box.new
gems.eval <<~'CODE'
  module Included
    def shared_order = ['include']
  end
  module First
    def shared_order = ['first', *super]
    def self.prepended(base)
      (@receivers ||= []) << [base, Ruby::Box.current]
    end
    def self.receivers = @receivers
  end
  module Second
    def shared_order = ['second', *super]
  end
  String.include(Included)
  String.prepend(First)
  String.prepend(Second)
CODE
billing, shipping = Array.new(2) { Ruby::Box.new }
[billing, shipping].each do |box|
  install =
    box.eval(
      '->(included, first, second) { String.include(included); String.prepend(first); String.prepend(second) }',
    )
  2.times do
    install.call(*%i[Included First Second].map { |n| gems.const_get(n) })
  end
  equal(%w[second first include], box.eval('"".shared_order'))
  equal(gems.eval('String.ancestors'), box.eval('String.ancestors'))
  # Copying the prepend method onto the class as well breaks super.
  box.eval('->(m) { String.define_method(:shared_order, m) }').call(
    gems.eval('String.instance_method(:shared_order)'),
  )
  result = box.eval('"".shared_order')
  equal(%w[second first second include], result)
end
equal(false, ''.respond_to?(:shared_order))
assert(
  gems.const_get(:First).receivers.all? { |_, origin| origin.equal?(gems) },
)
puts 'PASS include/prepend order, repeated installation, super and callback context'
puts 'LIMIT copying a prepended method onto the class duplicates its super chain'
