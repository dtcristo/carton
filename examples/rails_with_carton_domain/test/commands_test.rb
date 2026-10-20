# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'tmpdir'

class RailsDomainCommandsTest < Minitest::Test
  APP = File.expand_path('..', __dir__)
  SCRIPT = File.join(APP, 'bin/rails')

  def test_standard_rails_commands
    Dir.mktmpdir('carton-rails-main') { |directory| check_commands(directory) }
  end

  private

  def check_commands(directory)
    env = {
      'RUBY_BOX' => '1',
      'RAILS_ENV' => 'test',
      'MAIN_DATABASE' => File.join(directory, 'test.sqlite3'),
    }
    %w[db:prepare db:migrate zeitwerk:check].each do |command|
      rails(env, command)
    end
    assert_includes rails(env, 'routes'), 'invoices'
    assert_includes rails(env, 'routes'), 'customers'
    code = <<~RUBY
      customer = Shop::Customers::Directory.new(customers: CustomerRepository.new).register(name: 'Ada')
      issue = Shop::Billing::IssueInvoice.new(invoices: InvoiceRepository.new, customers: CustomerRepository.new)
      puts issue.call(customer_id: customer.id, subtotal_cents: 4200).total_cents
    RUBY
    assert_includes rails(env, 'runner', code), '4620'
    assert_includes rails(
                      env,
                      'generate',
                      'model',
                      'Draft',
                      'name:string',
                      '--pretend',
                    ),
                    'create'
    %w[false true].each do |eager|
      # An explicit test path avoids running this subprocess check recursively.
      output =
        rails(
          env.merge('RAILS_EAGER_LOAD' => eager),
          'test',
          'test/integration/invoices_test.rb',
        )
      assert_match(/5 (?:runs|tests),/, output)
    end
  end

  def rails(env, *args)
    output, status =
      Open3.capture2e(env, RbConfig.ruby, SCRIPT, *args, chdir: APP)
    assert status.success?, "#{args.inspect} failed:\n#{output}"
    output
  end
end
