# frozen_string_literal: true

require_relative 'cli_helper'
class HanamiCommandsTest < Minitest::Test
  include HanamiCommandSupport

  def test_commands_and_persistence_in_fresh_processes
    Dir.mktmpdir('carton-hanami-commands') do |directory|
      env = environment(directory, name: 'development')
      # Development migrations also invoke the same bridge for Hanami's test database.
      hanami(env, 'db', 'migrate')
      hanami(env, 'db', 'migrate')
      routes = hanami(env, 'routes')
      assert_includes routes, '/customers'
      assert_includes routes, '/invoices/:id.json'
      seed = <<~RUBY
        customer = Hanami.app.slices[:customers]['operations.register_customer'].call(name: 'Ada').value!
        invoice = Hanami.app.slices[:billing]['operations.issue_invoice'].call(customer_id: customer.fetch(:id), subtotal_cents: 4200).value!
        puts "CREATED=\#{invoice.fetch(:id)}"
      RUBY
      assert_includes hanami(env, 'run', seed), 'CREATED=1'
      read = <<~RUBY
        require 'rack'
        response = Rack::MockRequest.new(Hanami.app).get('/invoices/1.json')
        raise response.body unless response.status == 200
        puts "INVOICE=\#{response.body}"
      RUBY
      output = hanami(env, 'run', read)
      assert_includes output, '"tax_cents":420'
      assert_includes output, '"total_cents":4620'
    end
  end

  def test_eager_boot_runs_the_same_request_and_isolation_suite
    env = { 'RUBY_BOX' => '1', 'HANAMI_EAGER_LOAD' => 'true' }
    output, status =
      Open3.capture2e(
        env,
        RbConfig.ruby,
        File.join(APP, 'test/workflow_test.rb'),
      )
    assert status.success?, output
    assert_match(/8 runs, \d+ assertions, 0 failures, 0 errors/, output)
  end
end
