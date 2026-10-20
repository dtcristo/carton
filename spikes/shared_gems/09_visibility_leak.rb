# frozen_string_literal: true

require_relative 'assertions'
# Reproduce a VM isolation failure in its own process. Do not create more Boxes
# after changing visibility, because RubyGems startup itself calls String#upcase.
gems = Ruby::Box.new
shipping = Ruby::Box.new
equal(true, String.public_method_defined?(:upcase))
gems.eval('class String; protected :upcase; end')
equal(false, String.public_method_defined?(:upcase))
equal(true, shipping.eval('String.protected_method_defined?(:upcase)'))
equal(true, Ruby::Box.master.eval('String.protected_method_defined?(:upcase)'))
puts 'VERIFIED FAILURE visibility-only change to String#upcase leaks to Main, Shipping and Master on Ruby 4.0.7'
