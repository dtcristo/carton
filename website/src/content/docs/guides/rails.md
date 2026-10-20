---
title: Rails
description: Compare the same Customers and Billing workflow with Rails in Main or Rails Engines inside Cartons.
sidebar:
  order: 9
---

The two Rails examples implement the same application with two domain Cartons, Customers and Billing. Customers registers a customer; Billing imports Customers, validates an invoice, calculates tax, and persists it. Both expose the same requests, responses, business rules, and HTML view. Their difference is where Rails application code runs.

| | [Rails with Carton domains](https://github.com/dtcristo/carton/tree/main/examples/rails_with_carton_domain) | [Rails Engines in Cartons](https://github.com/dtcristo/carton/tree/main/examples/rails_in_cartons) |
| --- | --- | --- |
| Rails implementation | Main Box | Shared framework Carton |
| Customers and Billing business code | Separate Carton Boxes | Separate Carton Boxes |
| Controllers, storage records, repositories | Main Box | Their domain Carton Boxes |
| Rails commands | Ordinary `bin/rails` | Example-local `bin/rails` bridge |

For adding Carton to an existing Rails app, start with Rails with Carton domains. Use the Engine example to explore moving Rails application code into the domains too.

## The shared application

| Request | Behavior |
| --- | --- |
| `POST /customers`, `customer: { name: "Ada" }` | Register a customer and return its ID and trimmed name, status 201 |
| `POST /invoices.json`, `invoice: { customer_id: 1, subtotal_cents: 4200 }` | Issue an invoice and return its values, status 201 |
| `GET /invoices/1.json` | Return the issued invoice, status 200 |
| `GET /invoices/1` | Render its total and escaped customer name as HTML |

Invoice JSON contains `id`, `customer_id`, `subtotal_cents`, `tax_cents`, and `total_cents`. Tax is ten percent, rounded half up using integer cents. A subtotal of 4200 produces tax of 420 and a total of 4620. The stored tax is retained when an invoice is read later.

Blank customer names and invalid subtotals return 422 with domain errors. Subtotals must be non-negative Integers after the controller coerces form strings; fractional and malformed values are rejected. Issuing an invoice for an unknown customer returns 404. Neither Carton holds per-request repositories in module-level state.

## Rails with Carton domains

The conventional Rails host owns HTTP and Active Record, while the two plain-Ruby Cartons own business decisions. Make each domain a path gem and keep `Bundler.require` from loading its source into Main:

```ruby title="Gemfile"
gem 'carton'
gem 'customers', path: 'components/customers', require: false
gem 'billing', path: 'components/billing', require: false
```

Require Carton after Bundler in `config/application.rb`. At boot, import the domains inside the app's namespace because Rake also defines a top-level `import`:

```ruby title="config/initializers/billing.rb"
module Shop
  Billing = import 'billing'
  Customers = import 'customers' # Shared Import of Billing's Imported Carton
end
```

Each domain declares Carton and Zeitwerk in its gemspec; Billing also declares Customers. Each owns a Zeitwerk loader for its Interior. Billing's Import of Customers is private, and its Entrypoint exports only Billing. The Rails app never autoloads either domain's files.

The host injects repositories through the exported workflow:

```ruby
customer = Shop::Customers::Directory.new(customers: CustomerRepository.new).register(name: 'Ada')
issue = Shop::Billing::IssueInvoice.new(invoices: InvoiceRepository.new, customers: CustomerRepository.new)
invoice = issue.call(customer_id: customer.id, subtotal_cents: 4200)
```

Billing resolves the customer through Customers' Directory, validates the subtotal, calculates tax, and asks its repository to persist the invoice. The injected objects' methods execute in Main, where they can resolve the app's Active Record classes. Repository calls exchange integer IDs and plain attribute Hashes, and returned domain objects stay ordinary Ruby objects.

Controllers handle parameters, status codes, and rendering. Active Record models describe storage and associations. Business validation is tested through the Cartons' exports with in-memory repositories, without booting Rails. See [Passing application services](/guides/sharing-classes/#passing-application-services) for the same injection pattern outside Rails.

After installing the example's bundle:

```sh
cd examples/rails_with_carton_domain
RUBY_BOX=1 ruby test/billing_test.rb
RUBY_BOX=1 ruby test/customers_test.rb
RUBY_BOX=1 bin/rails db:prepare
RUBY_BOX=1 bin/rails routes
RUBY_BOX=1 bin/rails test
RUBY_BOX=1 bin/rails server -b 127.0.0.1
```

Development and test use separate SQLite databases. `MAIN_DATABASE` selects another database. The example README documents resetting a disposable database from the former `rails_in_main` example.

## Rails Engines in Cartons

The Engine variant runs the same application with Customers and Billing as isolated Rails Engines. Rails loads once in a shared framework Carton. Each domain owns its business classes, controllers, storage records, repositories, routes, views, and migrations. A shop Carton mounts both Engines and exports its Rack application.

Engine namespace isolation alone does not choose a Ruby Box. Each Engine Carton uses its own Zeitwerk loader and configures Rails' main loader to ignore its Ruby application directories. Rails still manages Engine discovery, route files, mounts, templates, and migration tasks. Explicit namespace registration lets framework code resolve qualified record and controller names across the domains.

The repository contracts and business classes match the conventional-host example. Their methods execute beside the Engine's storage models, in the domain's Carton Box; inherited Rails implementations execute in the framework Box. Framework classes and registries remain shared mutable Ruby objects. [Reopening shared classes](/guides/sharing-classes/) still affects their holders.

```sh
cd examples/rails_in_cartons/components/shop
RUBY_BOX=1 bin/rails db:prepare
RUBY_BOX=1 bin/rails routes
RUBY_BOX=1 bin/rails test
RUBY_BOX=1 bin/rails server -b 127.0.0.1
```

Use the example's `bin/rails`. It enters the framework Carton before loading Rails commands, and supplies the explicitly exported namespaces to `runner`. Stock Rails/Rake commands, interactive console, generators, and arbitrary third-party Engines are outside that example's verified contract. `SHOP_DATABASE` selects its database; its README lists the commands and layout.

## Testing and development

Run both examples, including their demos and tests, from the repository root:

```sh
bundle exec rake example:rails_with_carton_domain
bundle exec rake example:rails_in_cartons
```

Both verify the same customer/invoice requests, invalid inputs, unknown customers, stored pricing, escaped HTML, associations, and Box ownership under lazy and eager loading. Command tests exercise migrations, routes, runner, and Zeitwerk checks; Puma tests use real HTTP. The conventional-host example additionally tests a generator dry run and its plain-Ruby domain workflows.

Restart after edits. Rails reloading is disabled and Imports stay cached. A separate [reloading spike](https://github.com/dtcristo/carton/tree/main/spikes/rails_reloading) uses a scratch copy of the Engine app to investigate two serial reloads; ordinary examples never load its private hooks.

Both apps select their Railties explicitly and add no runtime patches. Full `rails/all` initialization on Ruby 4.0.7 with Boxes enabled can reach upstream issues through Action Cable and mail dependencies. Jobs, mailers, external workers, and other unrelated Rails features are outside these examples. Active Support extensions remain Box-local; domain code that needs them must declare and require them explicitly.
