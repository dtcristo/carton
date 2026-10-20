# Rails Engines in Cartons

Customers and Orders are isolated Rails Engines, each imported as a Gem Carton. Their models, controllers, jobs, and Zeitwerk loaders belong to separate Carton Boxes. Rails loads once in a framework Carton. A shop Carton composes the application and mounts both Engines; the ordinary Main Box receives its Rack application.

This is an experimental integration built with public Rails, Zeitwerk, and Carton APIs. It adds no runtime hooks or production Carton API. [Rails in Main](../rails_with_carton_domain/README.md) remains the simpler way to add Cartons to an existing Rails app.

## Layout

```text
main.rb                              # repeatable Rack demo with a temporary database
components/
  framework/lib/framework.rb          # Rails and shared base classes
  customers/
    customers.gemspec
    lib/customers.rb                 # Entrypoint: import framework, set up local loader, export Customers
    lib/customers/engine.rb           # Rails::Engine, isolate_namespace, loader ownership
    app/models/customers/            # ApplicationRecord and Customer
    app/controllers/customers/       # API controllers and HTML directory
    app/views/customers/              # ordinary ERB templates
    config/routes.rb
    db/migrate/
  orders/                            # same Engine shape; imports Customers, defines ReceiptJob
  shop/
    bin/rails                        # explicit CLI bridge into the framework Carton
    config/{boot,application,environment,routes}.rb
    config/database.yml
    config.ru
    Rakefile
    lib/shop.rb                      # Entrypoint: import Engines, export Shop::Application
    lib/shop/application.rb           # Rails application configuration inside the Carton
    test/integration/engines_test.rb
```

The Engines use normal namespaced classes, such as `Customers::Customer` and `Orders::Order`, and Rails' corresponding table prefixes. Orders explicitly imports Customers. Rails resolves both directions of their associations by qualified class name through the registered namespaces.

## Loader ownership

`isolate_namespace` isolates Rails names and routes; it does not choose a Ruby Box. Left unchanged, Rails' main loader would evaluate Engine application files in the framework Box. Each Carton therefore requires its own Zeitwerk, manages its `app/models`, `app/controllers`, and `app/jobs`, and asks `Rails.autoloaders.main.ignore` to leave those directories alone. An Engine initializer eager loads that local loader when the app requests eager loading. Otherwise its autoloads remain local to the Carton.

Rails still discovers the Engines, loads their conventional `config/routes.rb`, mounts their routes, and finds their view templates. `Framework.register(Customers, Orders, Shop)` binds the exported namespace objects in the framework Box for Rails' qualified-name lookups. It rejects collisions and does not flatten their classes into top-level constants.

`config/application.rb` imports the shop Entrypoint instead of requiring it outside its boundary. The application class lives in `lib/shop/application.rb`, inside the shop Carton's Interior. Models and jobs subclass explicitly shared Rails base classes. Their own method bodies execute in their Cartons; inherited framework methods execute next to Rails.

## Run

From the repository root:

```sh
bundle exec rake example:rails_in_cartons
```

This installs the locked bundle, runs a Rack demo with a temporary SQLite database, and checks the Rails commands and integration tests in fresh processes. The tests run with both lazy and eager loading.

For a persistent local application, after bundle installation:

```sh
cd examples/rails_in_cartons/components/shop
RUBY_BOX=1 bin/rails db:prepare
RUBY_BOX=1 bin/rails routes
RUBY_BOX=1 bin/rails runner 'puts Customers::Customer.count'
RUBY_BOX=1 bin/rails zeitwerk:check
RUBY_BOX=1 bin/rails test
RUBY_BOX=1 bin/rails server -b 127.0.0.1
```

Visit `/customers/directory`, POST `/customers`, and POST or GET `/orders`. The JSON endpoints take `name`, or `customer_id` and `total_cents`. `Orders::ReceiptJob.perform_later(order)` demonstrates the inline Active Job adapter; the integration test also serializes and deserializes a job's model argument through GlobalID.

The app's migration paths point at both Engines' real `db/migrate` directories. `db:prepare` and `db:migrate` use Rails' normal migration tracking. Importing the application does not create tables. Development and test use separate files under `shop/storage/`; set `SHOP_DATABASE` to choose a temporary database. Generated databases, schemas, and logs are ignored.

## CLI contract

Use this app's `bin/rails`. It enters the framework Carton before requiring Rails commands, sets Rails' standard `APP_PATH` bootstrap constant there, and gives Main explicit references to the exported Rails and domain modules for `runner`'s top-level binding. Rails source still loads only in the framework Carton. The ordinary Rack host does not bind Rails in Main.

The verified commands are `db:prepare`, `db:migrate`, `routes`, `runner`, `zeitwerk:check`, `test`, and `server` with Puma. This is example-local boot wiring, not a general Carton Rails CLI. Stock `bundle exec rails`, direct `rake`, interactive console, and Engine generators are not covered. Imports live inside modules because Rake also defines a top-level `import` method.

## Limits

- Restart after changes. Rails reloading is disabled because Importers and Rails retain class objects. The separate [reloading spike](../../spikes/rails_reloading/README.md) uses a scratch copy to investigate serial model/controller replacement; it is not loaded by this app.
- Core extensions are Box-local. Customers explicitly requires `active_support/core_ext/object/blank` for `Customer#display_name`; the application does not transplant Rails' patches into domain Boxes.
- Shared Rails classes and registries remain shared mutable Ruby objects. This is definition isolation for application code, not a process sandbox or fully isolated framework runtime.
- Active Job uses an inline adapter. External queues, worker processes, assets, Action Cable, Active Storage, and other Rails subsystems have no compatibility claim here.
- Action Mailer is deferred. Basic delivery worked during investigation, but eager loading reaches a `net-imap` crash under Ruby 4.0.7 with Boxes enabled, even without Carton ([Ruby #22260](https://bugs.ruby-lang.org/issues/22260)). No workaround is installed.

The integration tests cover mounted requests, validation errors, escaped HTML, associations, serialized jobs, and defining-Box provenance. The command test prepares and remigrates a temporary database, checks routes and runner import identity, and runs those tests with lazy and eager loading.
