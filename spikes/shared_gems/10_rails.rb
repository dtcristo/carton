# frozen_string_literal: true

require_relative 'shared_gems_prototype'
require_relative '../../lib/carton'
require 'tmpdir'
started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
shared =
  SharedGemsPrototype.new(
    gemfile: File.expand_path('../../examples/rails/Gemfile', __dir__),
    extra_builtins: %w[Enumerable Range Float Regexp],
  )
shared.load(
  'active_support',
  'active_support/core_ext',
  'rails',
  'active_record/railtie',
  'action_controller/railtie',
  'sqlite3',
)
dependencies_loaded = Process.clock_gettime(Process::CLOCK_MONOTONIC)
shared.box.eval <<~CODE
  ActiveRecord::Base.establish_connection(adapter: 'sqlite3', database: ':memory:')
  ActiveRecord::Schema.define do
    create_table(:invoices) { |t| t.string :name }
  end
CODE
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
if ARGV.include?('--existing')
  load File.expand_path('../../examples/rails/main.rb', __dir__)
  exit
end
Dir.mktmpdir('shared-gems-rails') do |dir|
  2.times do |i|
    path = File.join(dir, "domain_#{i}.rb")
    File.write(path, <<~CODE)
      class Invoice < ActiveRecord::Base
        self.table_name = 'invoices'
        def valid_name? = name.present?
      end
      export Invoice
    CODE
    invoice = import(path)
    record = invoice.create!(name: "invoice-#{i}")
    equal(true, record.valid_name?)
    equal(i + 1, invoice.count)
  end
end
equal(false, Object.const_defined?(:ActiveRecord))
equal(false, ''.respond_to?(:blank?))
puts format(
       'Dependency initialization %<init>.3fs; total with two persisted domain models %<total>.3fs',
       init: dependencies_loaded - started,
       total: Process.clock_gettime(Process::CLOCK_MONOTONIC) - started,
     )
puts 'PASS Rails dependencies and sqlite3 shared across two Active Record domain Cartons'
