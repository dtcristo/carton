# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative '../../../lib/carton'

# The Rails example is a read-only fixture. Edit only its scratch copy.
scratch = File.realpath(Dir.mktmpdir('carton-rails-reloading'))
at_exit { FileUtils.remove_entry(scratch) }
fixture = File.expand_path('../../../examples/rails', __dir__)
root = File.expand_path('../../..', __dir__)
FileUtils.cp_r(File.join(fixture, 'components'), scratch)
%w[framework shop].each do |name|
  entrypoint = File.join(scratch, "components/#{name}/lib/#{name}.rb")
  hook = File.expand_path("../hooks/#{name}.rb", __dir__)
  File.open(entrypoint, 'a') { |file| file.puts "\nrequire #{hook.inspect}" }
end
gemfile = File.read(File.join(fixture, 'Gemfile'))
File.write(
  File.join(scratch, 'Gemfile'),
  gemfile.sub("path: '../..'", "path: #{root.inspect}"),
)
lock = File.read(File.join(fixture, 'Gemfile.lock'))
File.write(
  File.join(scratch, 'Gemfile.lock'),
  lock.sub("remote: ../..\n", "remote: #{root}\n"),
)
ENV['SHOP_DATABASE'] = ':memory:'
ENV['RAILS_ENV'] = 'test'
Carton.setup_bundle(gemfile: File.join(scratch, 'Gemfile'))
require 'minitest/autorun'
require 'rack'
require 'json'

class RailsReloadingSpikeTest < Minitest::Test
  ROOT = Bundler.root.to_s

  def test_next_request_uses_reloaded_domains_and_keeps_records
    require_relative '../hooks/imports'
    imports =
      ReloadingSpike::Imports.new(
        reloadable:
          %w[customers billing].map do |name|
            File.join(ROOT, "components/#{name}/lib/#{name}.rb")
          end,
      )
    shop = import 'shop'
    framework = import 'framework'
    migrations =
      %w[customers billing].map do |name|
        File.join(ROOT, "components/#{name}/db/migrate")
      end
    framework::ActiveRecord::MigrationContext.new(migrations).migrate
    http =
      Rack::MockRequest.new(
        ->(env) { shop.call(env.merge('HTTP_HOST' => 'example.org')) },
      )

    customer =
      http.post(
        'http://example.org/customers',
        params: {
          customer: {
            name: 'Ada',
          },
        },
      )
    assert_equal 201, customer.status
    invoice =
      http.post(
        'http://example.org/invoices.json',
        params: {
          invoice: {
            customer_id: 1,
            subtotal_cents: '4200',
          },
        },
      )
    assert_equal 201, invoice.status
    assert_includes http.get('http://example.org/invoices/1').body,
                    'Customer: Ada'

    # Warm the belongs_to reflection, then change a model and controller.
    customers = import 'customers'
    billing = import 'billing'
    framework = import 'framework'
    old_customer = customers::CustomerRecord.find(1)
    assert_same customers::CustomerRecord,
                billing::InvoiceRecord.reflect_on_association(:customer).klass
    file =
      File.join(
        ROOT,
        'components/customers/app/models/customers/customer_record.rb',
      )
    File.write(
      file,
      File.read(file).sub(
        'def display_name = name.to_s.strip',
        'def display_name = name.to_s.strip.upcase',
      ),
    )
    controller =
      File.join(
        ROOT,
        'components/billing/app/controllers/billing/invoices_controller.rb',
      )
    File.write(
      controller,
      File.read(controller).sub(
        "def show\n",
        "def show\n    response.set_header('X-Carton-Reload', Customers::CustomerRecord.find(1).display_name)\n",
      ),
    )

    imports.reload(
      File.join(ROOT, 'components/customers/lib/customers.rb'),
      host: shop,
    )

    response = http.get('http://example.org/invoices/1')
    assert_equal 200, response.status
    assert_includes response.body, 'Customer: ADA'
    assert_equal 'ADA', response.headers['x-carton-reload']
    refute_same customers, import('customers')
    refute_same billing, import('billing')
    assert_same import('customers')::CustomerRecord,
                import('billing')::InvoiceRecord.reflect_on_association(
                  :customer,
                ).klass
    assert_same import('billing')::InvoiceRecord,
                import('customers')::CustomerRecord.reflect_on_association(
                  :invoices,
                ).klass
    assert_same shop, import('shop')
    assert_same framework, import('framework')
    assert_equal 'Ada', old_customer.display_name

    # A second edit rebuilds the already-rebuilt domains and registers their
    # new classes with the retained framework again.
    File.write(file, File.read(file).sub('strip.upcase', 'strip.downcase'))
    imports.reload(
      File.join(ROOT, 'components/customers/lib/customers.rb'),
      host: shop,
    )
    response = http.get('http://example.org/invoices/1')
    assert_equal 200, response.status
    assert_includes response.body, 'Customer: ada'
    assert_equal 'ada', response.headers['x-carton-reload']
    assert_same shop, import('shop')
    assert_nil defined?(Rails)
  ensure
    imports&.close
  end
end
