# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require_relative '../../../lib/carton'

# The Rails example is a read-only fixture. Edit only its scratch copy.
scratch = Dir.mktmpdir('carton-rails-reloading')
at_exit { FileUtils.remove_entry(scratch) }
fixture = File.expand_path('../../../examples/rails_in_cartons', __dir__)
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
          %w[customers orders].map do |name|
            File.join(ROOT, "components/#{name}/lib/#{name}.rb")
          end,
      )
    shop = import 'shop'
    http = Rack::MockRequest.new(shop)

    assert_equal 201, http.post('/customers', params: { name: 'Ada' }).status
    assert_equal 201,
                 http.post(
                   '/orders',
                   params: {
                     customer_id: 1,
                     total_cents: 4_200,
                   },
                 ).status
    assert_equal 'Ada',
                 JSON
                   .parse(http.get('/orders').body)
                   .first
                   .dig('customer', 'name')

    # Warm the belongs_to reflection, then change a model and controller.
    customers = import 'customers'
    orders = import 'orders'
    framework = import 'framework'
    old_customer = customers::Customer.find(1)
    assert_same customers::Customer,
                orders::Order.reflect_on_association(:customer).klass
    file = File.join(ROOT, 'components/customers/app/models/customer.rb')
    File.write(
      file,
      File.read(file).sub(
        'has_many :orders',
        "def name = super.upcase\n  has_many :orders",
      ),
    )
    controller =
      File.join(ROOT, 'components/orders/app/controllers/orders_controller.rb')
    File.write(
      controller,
      File.read(controller).sub(
        "def index\n",
        "def index\n    response.set_header('X-Carton-Reload', Customer.find(1).name)\n",
      ),
    )

    imports.reload(
      File.join(ROOT, 'components/customers/lib/customers.rb'),
      host: shop,
    )

    response = http.get('/orders')
    assert_equal 200, response.status
    assert_equal 'ADA', JSON.parse(response.body).first.dig('customer', 'name')
    assert_equal 'ADA', response.headers['x-carton-reload']
    refute_same customers, import('customers')
    refute_same orders, import('orders')
    assert_same import('customers')::Customer,
                import('orders')::Order.reflect_on_association(:customer).klass
    assert_same import('orders')::Order,
                import('customers')::Customer.reflect_on_association(
                  :orders,
                ).klass
    assert_same shop, import('shop')
    assert_same framework, import('framework')
    assert_equal 'Ada', old_customer.name

    # A second edit rebuilds the already-rebuilt domains and registers their
    # new classes with the retained framework again.
    File.write(file, File.read(file).sub('super.upcase', 'super.downcase'))
    imports.reload(
      File.join(ROOT, 'components/customers/lib/customers.rb'),
      host: shop,
    )
    response = http.get('/orders')
    assert_equal 200, response.status
    assert_equal 'ada', JSON.parse(response.body).first.dig('customer', 'name')
    assert_equal 'ada', response.headers['x-carton-reload']
    assert_same shop, import('shop')
    assert_nil defined?(Rails)
  ensure
    imports&.close
  end
end
