# Zeitwerk example

An app that already autoloads its code with Zeitwerk can move parts of it
into Cartons without giving Zeitwerk up. A Carton has Zeitwerk's gem layout,
so its Entrypoint can run a loader of its own. Three things then need care:

- The app's loader must not load a Carton's files into the Main Box.
- A constant a Carton leaves to autoload loads in whichever Box first
  references it, which can be the app's.
- Reloading a Carton replaces its classes, but importers keep the old ones.

This example shows each, with no Rails involved. `main.rb` raises if any
behavior below stops holding.

```
Gemfile                      # carton, zeitwerk 2.8.3 for the app
main.rb                      # the app's loader for lib/, then the imports
lib/
  order_summary.rb           # the app's own code, autoloaded in the Main Box
  shipping.rb                # shipping Carton's Entrypoint: reloadable loader
  shipping/rate.rb           # inside the shipping Carton
cartons/billing/
  Gemfile                    # zeitwerk 2.7.5 for this Carton only
  lib/billing.rb             # billing Carton's Entrypoint: Zeitwerk::Loader.for_gem
  lib/billing/invoice.rb     # eager loaded inside the Carton
  lib/billing/archive.rb     # left lazy, to show where an autoload runs
```

## A Carton with `Zeitwerk::Loader.for_gem`

`cartons/billing/lib/billing.rb` calls `Zeitwerk::Loader.for_gem`, sets it up,
eager loads, and ends with `export_default Billing`. Nothing else is needed:
`lib/billing.rb` plus `lib/billing/` is both a Carton and a Zeitwerk gem.
Keep one Carton per `lib/`, since `for_gem` manages the whole directory.

## Each Box has its own Zeitwerk

Every Box requires Zeitwerk separately and gets its own `Zeitwerk` module,
loader registry, and `Kernel#require` patch. The billing Carton runs zeitwerk
2.7.5 from its own Gemfile while the app runs 2.8.3. The shipping Carton sets
up the app's Gemfile in its own Box and gets a second copy of 2.8.3.
`Zeitwerk::Loader.all_dirs` in each Box lists only that Box's loaders:

| Box | `Zeitwerk::VERSION` | `Zeitwerk::Loader.all_dirs` |
| --- | --- | --- |
| Main | 2.8.3 | `lib` |
| billing | 2.7.5 | `cartons/billing/lib` |
| shipping | 2.8.3 | `lib/shipping` |

## The app's loader and a Carton in its directory

The app's loader manages `lib/`, and the shipping Carton lives in `lib/` too.
Left alone, the app's loader defines an autoload for `Shipping` pointing at
`lib/shipping.rb`. Anything in the app that touches `Shipping` before the
import, including `app_loader.eager_load`, then runs the Entrypoint in the
Main Box, outside any Carton. In this example that fails loudly: the
Entrypoint's own `push_dir` lands inside the app loader's root, and Zeitwerk
raises `Zeitwerk::Error` ("wants to manage directory .../lib/shipping, which
is already managed by" the app's loader). A Carton that used `require_relative`
instead would load a second copy without any error.

`main.rb` happens to import before anything references `Shipping`, and the
assignment `Shipping = import_relative 'lib/shipping'` replaces the pending
autoload, so the example would run without a fix. That depends on load order.
The fix is to tell the app's loader the Carton is not its code:

```ruby
app_loader.push_dir(lib)
app_loader.ignore(File.join(lib, 'shipping.rb'), File.join(lib, 'shipping'))
```

Ignore both the Entrypoint and its directory. `main.rb` checks that the Main
Box has no autoload for `Shipping` and, after the app's eager load, that no
Carton file is in the Main Box's `$LOADED_FEATURES`. A Carton outside the
app's loader roots, like `cartons/billing`, needs nothing.

## Eager load inside the Carton

Ruby runs an autoload in the Box whose code references the constant, not
the Box that defined the autoload. Plain `Module#autoload` behaves the same
way, so this is Ruby::Box behavior, not Zeitwerk's. `Billing::Archive` is left
lazy to show it: `main.rb` references it first, so `archive.rb` runs in the
Main Box. The Carton's loader never sees that load, and any `require` or
top-level constant in the file resolves against the Main Box. If the app had
bound the Carton to another name, `module Billing` in `archive.rb` would open
a new Main Box module and the autoload would raise `NameError`.

Call `loader.eager_load` at the end of the Entrypoint. Every file then loads
while the Carton's Box is running, before `import` returns, and importers only
ever read constants that already exist. `Billing::Invoice` and
`Shipping::Rate` record `Ruby::Box.current` when their files run, and neither
is the Main Box. Code inside a Carton, such as a method the Carton defines,
can still autoload lazily: it runs in the Carton's Box.

## Reloading

`Shipping.reload!` calls `loader.reload` and `loader.eager_load`. The block
was defined in the shipping Carton's Box, so it runs there even though
`main.rb` calls it. After a reload:

- `Shipping` is the same module. Its Entrypoint defines it and the loader
  manages only `lib/shipping/` inside it, via
  `push_dir(..., namespace: Shipping)`.
- `Shipping::Rate` is a new class, loaded again in the Carton's Box.
- A reference the importer kept, such as `held = Shipping::Rate`, is the old
  class and still runs the old code. Instances made before the reload are
  instances of the old class, so `is_a?(Shipping::Rate)` is false for them.

So reloading refreshes a Carton's internals for code that looks constants up
through the Carton's root module each time. It does not update constants,
instance variables, or objects an importer already holds. Carton caches each
import, so `import` after a reload returns the same root module, not a new
one.

Two setups do not reload:

- A `for_gem` loader manages the Entrypoint too. Reloading removes the
  top-level `Billing` from the Carton's Box, and the `Billing` module
  importers hold loses its autoloaded constants, so `Billing::Invoice` raises
  `NameError` for them. Loading `Billing` again re-runs the Entrypoint, which
  fails either way. Eager loading it calls `enable_reloading` while the
  loader is busy and raises `ThreadError` ("deadlock; recursive locking");
  Zeitwerk does the same without Boxes, since a loader cannot reload the
  file that configures it. Autoloading it lazily reaches `export_default` a
  second time, which raises `Carton::ExportError`. Use
  `push_dir(..., namespace:)` for a reloadable Carton.
- A lazy Carton. After the reload, the first reference from the app runs the
  file in the Main Box, as above. Eager load again after each reload.

## Run

```sh
RUBY_BOX=1 ruby examples/zeitwerk/main.rb
```
