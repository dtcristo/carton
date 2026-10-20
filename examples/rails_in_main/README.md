# Rails in Main

A conventional Rails app owns persistence, controllers, HTML views, and jobs in Main. Billing is a path-gem Carton with a separate Zeitwerk loader and a plain-Ruby invoice calculation. It cannot resolve the app's Rails constants or models. See the canonical [Rails guide](https://carton.dtcristo.com/guides/rails/) for the integration model.

## App structure

```text
bin/rails                         # ordinary Rails command loader
config/{boot,application,environment,routes}.rb
config/environments/{development,test}.rb
config/initializers/billing.rb    # Shop::Billing = import 'billing'
config/database.yml
config.ru
Rakefile
app/models/invoice.rb            # Active Record, owned by Main
app/controllers/invoices_controller.rb
app/views/invoices/show.html.erb
app/jobs/invoice_audit_job.rb
db/migrate/
components/billing/
  billing.gemspec                 # carton and zeitwerk, with no Rails dependency
  lib/billing.rb                 # Entrypoint and Export
  lib/billing/invoice.rb          # plain Ruby value object
main.rb                          # repeatable demo using a temporary database
test/                            # Rails integration, command, and real HTTP tests
```

`Invoice#quote` passes its ID and subtotal to `Shop::Billing::Invoice`. HTML uses normal Rails view helpers, JSON uses the calculated value's `to_h`, and `InvoiceAuditJob` round-trips the host record through GlobalID before writing its audit timestamp. The private `Billing::TaxPolicy` remains hidden across the boundary.

The initializer imports inside `module Shop` because Rake also defines a top-level `import`. `Shop::Billing` is the Carton's exported module, while the app's `Invoice` is an ordinary, separate Active Record class. Rails never autoloads Billing's files.

## Run

From the repository root:

```sh
bundle exec rake example:rails_in_main
```

The task installs the bundle, runs the temporary-database demo, and runs the test files. Command checks cover migrations, routes, runner, Zeitwerk checks, generator dry runs, and the Rails integration suite with both lazy and eager loading. The HTTP test starts and stops Puma.

For a persistent local app after bundle installation:

```sh
cd examples/rails_in_main
RUBY_BOX=1 bin/rails db:prepare
RUBY_BOX=1 bin/rails runner 'puts Invoice.create!(subtotal_cents: 4200).id'
RUBY_BOX=1 bin/rails routes
RUBY_BOX=1 bin/rails test
RUBY_BOX=1 bin/rails server -b 127.0.0.1
```

Visit `/invoices/<id>` for HTML or `/invoices/<id>.json` for JSON. The example preserves normal Rails CSRF protection outside the test environment. Development and test use separate SQLite files in `storage/`; set `MAIN_DATABASE` to use a temporary database. Generated databases, schemas, and logs are ignored.

## Development and scope

Restart after edits, including changes to Billing. Rails reloading is disabled and Carton imports remain cached. The app's Railties are selected explicitly; full `rails/all` can reach Ruby 4.0.7 Box issues through Action Cable and mail dependencies. No runtime workaround is added here. Jobs use an inline adapter; external queues and mail delivery are outside this example.

The assertions check real HTTP/JSON/HTML behavior, model validation, job serialization, private constants, and defining-Box provenance. Rails and Active Support are available in Main, while Billing's Box has neither the app's Rails constants nor its core extensions.

Compare [Rails Engines in Cartons](../rails_in_cartons/README.md) for boxed framework and Engine application code with an explicit CLI bridge. This example uses Rails' ordinary command loader in Main.
