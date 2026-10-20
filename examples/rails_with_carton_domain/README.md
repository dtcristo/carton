# Rails with Carton domains

Customers and Billing own customer registration and invoice issuance in separate Cartons. A conventional Rails app in Main supplies HTTP, HTML templates, and Active Record repositories. Neither domain can resolve Rails models by name. Compare [Rails Engines in Cartons](../rails_in_cartons/README.md), which implements the same customer and invoice workflow with Rails application code inside the two domain Cartons.

## The workflow

1. `POST /customers` with `customer: { name: "Ada" }` registers a customer. Customers validates and trims the name before calling its injected repository.
2. `POST /invoices.json` with `invoice: { customer_id: 1, subtotal_cents: 4200 }` issues an invoice. Billing imports Customers, resolves the customer through its Directory, validates integer non-negative cents, calculates ten-percent tax rounded half up, and persists the invoice through an injected repository.
3. `GET /invoices/1.json` returns `id`, `customer_id`, `subtotal_cents`, `tax_cents`, and `total_cents`. `GET /invoices/1` renders HTML with an escaped customer name and the total.

A subtotal of 4200 produces tax of 420 and a total of 4620. Invalid customer names or subtotals return 422 with domain errors; an unknown customer returns 404. Tax is stored at issuance, so fetching an invoice does not apply a newer pricing rule.

## The boundary

```ruby
customer = Shop::Customers::Directory.new(customers: CustomerRepository.new).register(name: 'Ada')
issue = Shop::Billing::IssueInvoice.new(invoices: InvoiceRepository.new, customers: CustomerRepository.new)
invoice = issue.call(customer_id: customer.id, subtotal_cents: 4200)
```

The domain objects and orchestration execute in their Carton Boxes. The injected repositories execute in Main, where they can use the app's Active Record classes. Only integer IDs and plain attribute Hashes cross the repository interface. Each workflow instance receives its own repositories, so Shared Imports do not create shared per-request adapter state.

| Repository method | Result |
| --- | --- |
| `customers.create(name:)` | Customer ID |
| `customers.fetch(id)` | `{ id:, name: }`, or raises if missing |
| `invoices.create(customer_id:, subtotal_cents:, tax_cents:)` | Invoice ID |
| `invoices.fetch(id)` | `{ id:, customer_id:, subtotal_cents:, tax_cents: }`, or raises if missing |

Business validation belongs to Customers and Billing. Rails controllers coerce form strings, translate domain errors to HTTP responses, and render returned values. Active Record models describe storage and associations. Rails never autoloads the domains' files; each Carton owns its own Zeitwerk loader. Billing's imported Customers module and tax policy are private constants.

## Layout

```text
bin/rails                         # ordinary Rails command loader
config/initializers/billing.rb    # module-scoped Imports for Customers and Billing
app/controllers/                  # HTTP adapters in Main
app/models/                       # Main's Customer and Invoice storage records
app/repositories/                 # Main's Active Record adapters
app/views/invoices/show.html.erb
db/migrate/
components/customers/lib/         # Customers domain and its own loader
components/billing/lib/           # Billing domain, imports Customers
main.rb                          # temporary-database demo
test/billing_test.rb              # exported Billing workflow with a fake repository
test/customers_test.rb            # exported Customers workflow with a fake repository
test/integration/invoices_test.rb # requests, persistence, and Box isolation
test/{commands,server}_test.rb    # CLI and real Puma HTTP checks
```

## Run

From the repository root:

```sh
bundle exec rake example:rails_with_carton_domain
```

After bundle installation, the two domain tests run without booting Rails:

```sh
RUBY_BOX=1 ruby examples/rails_with_carton_domain/test/billing_test.rb
RUBY_BOX=1 ruby examples/rails_with_carton_domain/test/customers_test.rb
```

For a persistent local app:

```sh
cd examples/rails_with_carton_domain
RUBY_BOX=1 bin/rails db:prepare
RUBY_BOX=1 bin/rails routes
RUBY_BOX=1 bin/rails test
RUBY_BOX=1 bin/rails server -b 127.0.0.1
```

Development and test use separate SQLite files under `storage/`; `MAIN_DATABASE` selects a temporary database. Generated databases, schemas, and logs are ignored. This replaces the older `rails_in_main` demonstration. If you have a disposable database from that example, reset it with `bin/rails db:reset` under `RUBY_BOX=1` before using the new customer-associated invoices.

## Development and scope

Restart after edits. Rails reloading is disabled and Imports remain cached. Boot Imports live inside `module Shop` because Rake also defines a top-level `import`. The app uses Rails' ordinary command loader; no framework sharing or runtime patch is added.

The example selects its Railties explicitly; full `rails/all` can reach Ruby 4.0.7 Box issues through Action Cable and mail dependencies. Jobs, mailers, and other unrelated Rails features are outside this example. The [Engine variant](../rails_in_cartons/README.md) runs the same business scenario with a different ownership and loading arrangement.

Tests cover domain validation, exact cent arithmetic, storage failures, instance-local adapters, JSON/HTML requests, stored pricing, private constants, and defining-Box provenance. CLI checks exercise migrations, routes, runner, Zeitwerk, generator dry runs, and requests with lazy and eager loading; the server test starts and stops Puma.
