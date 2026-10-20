# frozen_string_literal: true

# The handoff's first probe, with its expected semantics unchanged.
raise 'Ruby::Box is required' unless Ruby::Box.enabled?
gems = Ruby::Box.new
gems.eval <<~'CODE'
  module SharedDependency
    MARKER = "from-gems"
  end
  class String
    def shared_probe
      "#{SharedDependency::MARKER}:#{upcase}"
    end
  end
CODE
method = gems.eval('String.instance_method(:shared_probe)')
raise 'Wrong defining Box' unless method.box.equal?(gems)
billing = Ruby::Box.new
installer = billing.eval <<~'CODE'
  ->(method) do
    String.send(:define_method, :shared_probe, method)
  end
CODE
installer.call(method)
result = billing.eval('"hello".shared_probe')
raise "Unexpected result: #{result.inspect}" unless result == 'from-gems:HELLO'
unless billing.eval('String.instance_method(:shared_probe).box').equal?(gems)
  raise 'Method is not shared'
end
if Ruby::Box.main.eval('"hello".respond_to?(:shared_probe)')
  raise 'Leaked into Main'
end
puts 'Method transplantation works'
