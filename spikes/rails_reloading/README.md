# Rails reloading spike

This experiment answers whether changed domain Cartons and their Importers can be rebuilt while an initialized Rails application keeps serving requests. Yes, for the serial model-and-controller edits exercised here, if the retained host explicitly replaces its domain references and Rails' registered namespaces. Evicting imports alone cannot update objects already returned to Importers.

## Run

From the repository root, run the dedicated task:

```sh
bundle exec rake spike:rails_reloading
```

The task installs the Rails fixture bundle and runs only this spike's request-level regression test in a fresh process. With the bundle already installed:

```sh
RUBY_BOX=1 ruby spikes/rails_reloading/test/reloading_test.rb
```

The test uses [the Rails-in-Cartons example](../../examples/rails_in_cartons/README.md) as a read-only fixture. It copies that app's Cartons and lockfile into a temporary directory, points the scratch Gemfile at this checkout, and installs the experiment's hooks in that copy only. It edits those copied files, uses an in-memory database, and deletes the copy on exit. The ordinary example still requires restarting after edits.

## Ownership and fixture dependency

This directory owns the experimental reload observer, host/framework hooks and regression test. The fixture app and its resolved dependencies remain in `examples/rails_in_cartons/`; copying them here would create a second Rails app to maintain. The fixture files are read, copied into temporary storage, and never edited in place. Only the scratch entrypoints load `hooks/shop.rb` and `hooks/framework.rb`, using absolute paths to this directory.

The ordinary `example:rails_in_cartons` task runs the Rails app without loading or testing this experiment. Both Rails examples stay under `examples/`. `bundle exec rake spikes` runs this experiment and Master prelude in separate processes, and CI runs that task separately from the default checks. The Shared Gems experiment retains its own documented runner.

## What it proves

- Create a customer and invoice through HTTP, then warm the invoice's customer association and the billing controller.
- Change the customer storage model's `display_name` method and the billing controller in the scratch files.
- Follow observed Imports backwards from `customers` to `billing` and `shop`. Evict `customers` and `billing`; retain `shop` and `framework`.
- Ask the retained `shop` to import the domains again and replace both its domain references and the domain namespace objects registered in the framework Box.
- Send another request through the same Rack client and Rails application. Its HTML uses the changed customer method and its response header comes from the changed controller. Previously created records remain, and both directions of the new model associations resolve to the new classes.
- Edit the model again and repeat the reload. The next request uses that edit too. Rails stays out of the Main Box.

The previous customer object deliberately retains its old behavior. Existing objects cannot be rewritten by evicting their Cartons; the host must stop using them at the reload boundary. The experiment needs no Rails cache clearing for these routes and associations because it replaces both domain Boxes and registers their new classes.

## How the experiment works

`hooks/imports.rb` uses a `TracePoint` on returns from Carton's private `Runtime.import` to record Imports, including Shared Imports. It reads the importing Carton Box's Entrypoint and the resolved target from the runtime frame. It computes the affected Importers and removes the selected domains' cached values and gem-usage records. It refuses an affected Carton outside the declared reloadable domains and retained host, and refuses eviction while an Import is loading.

`hooks/shop.rb` runs inside the scratch shop Box. Its explicit callback replaces `Customers` and `Billing` there and asks the framework to replace the registered classes. `hooks/framework.rb` runs inside the scratch framework Box, where Rails constantizes model and controller names. Keeping these hooks in their respective Boxes matters: methods execute in the Box where they were defined.

The initialized Rails application is the retained boundary. Rebuilding the full Importer chain would run `Shop.initialize!` and Rails initialization again. The framework and shop therefore stay loaded, while the callback refreshes the references they own.

## Limits and next decisions

This is experiment code that reads private runtime state, not a supported reload interface. Reloads run between requests in one thread. The check for an active Import does not make eviction safe against a concurrently starting Import or request. The Import graph accumulates observed edges, including failed Imports, because a runtime return event also fires when an Import raises. The spike does not test removing an Import, a deleted or renamed class, lazy Imports, failed reload rollback, retained background jobs, other Rails caches, or reclaiming old Boxes and Zeitwerk loaders. Framework edits require restarting.

Before promoting this to runtime support, choose a host callback contract, track Imports without frame inspection, define graph replacement and concurrent-load behavior, and measure memory over repeated reloads. File watching, Rails reloader integration, `rails console`, generators, migrations, and Active Support extension costs remain separate work.

The fixture now contains isolated Rails Engines. The test applies their migrations once to an in-memory database and replaces the exported namespace bindings after each edit. It still tests only the existing routes and serial model/controller edits, not rebuilding mounted routes, rerunning Engine initializers, or changing jobs and migrations.
