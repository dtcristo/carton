# frozen_string_literal: true

require_relative 'shared_gems_prototype'
require 'tmpdir'
require_relative '../../lib/carton'
shared =
  SharedGemsPrototype.new(
    gemfile: File.expand_path('Gemfile', __dir__),
    extra_builtins: %w[Enumerable Range Float Regexp],
  )
shared.load('active_support', 'active_support/core_ext')
# Experimental hook, confined to this process. Production files stay unchanged.
hook =
  Module.new do
    define_method(:configure_for_import) do |**options|
      result = super(**options)
      shared.install(instance_variable_get(:@box))
      result
    end
    private :configure_for_import
  end
Carton.const_get(:Box).prepend(hook)
Dir.mktmpdir('shared-gems-cartons') do |dir|
  File.write(File.join(dir, 'billing.rb'), <<~CODE)
    class Invoice
      def valid_name?(name) = name.present?
      def days = 14.days.to_i
    end
    PRIVATE_VALUE = :billing
    export Invoice
  CODE
  File.write(File.join(dir, 'shipping.rb'), <<~CODE)
    Billing = import_relative 'billing'
    class Invoice
      def valid_name?(name) = name.present?
    end
    PRIVATE_VALUE = :shipping
    export Invoice
  CODE
  File.write(File.join(dir, 'bare.rb'), 'LOCAL = :only_local')
  billing = import(File.join(dir, 'billing.rb'))
  shipping = import(File.join(dir, 'shipping.rb'))
  equal(true, billing.new.valid_name?('hello'))
  equal(false, shipping.new.valid_name?(''))
  equal(1_209_600, billing.new.days)
  assert(!billing.equal?(shipping))
  assert(billing.equal?(import(File.join(dir, 'billing.rb'))))
  equal([:LOCAL], import(File.join(dir, 'bare.rb')).constants)
  equal(false, Object.const_defined?(:PRIVATE_VALUE))
  equal(false, ''.respond_to?(:blank?))
end
puts 'PASS two plain Cartons, nested import, cache identity, local constants, exports and Bare Carton discovery'
# A real Gem Carton still passes through the existing activation lifecycle.
if ARGV.include?('--gem')
  Carton.setup_bundle(
    gemfile:
      File.expand_path('../../test/fixtures/shared_gems/Gemfile', __dir__),
  )
  priced = import('priced_gem')
  equal('3.3.1', priced[:bigdecimal_version])
  equal('3.3.1', priced[:activated])
  puts 'PASS existing Gem Carton activation with shared definitions installed'
end
