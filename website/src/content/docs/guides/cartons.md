---
title: Cartons
description: What a Carton is, what belongs to it, and how Zeitwerk loaders work inside one.
sidebar:
  order: 1
---

A Carton is an Entrypoint file plus the directory named after it, the same shape as a gem's `lib/` and a Zeitwerk explicit namespace:

```
lib/billing.rb                # the Entrypoint
lib/billing/invoice.rb        # inside the billing Carton
lib/billing/models/charge.rb  # inside too: models/ has no models.rb
```

- The Entrypoint loads the Carton's other files with `require`, `require_relative`, or a Zeitwerk loader, all inside the Carton's one Box.
- Only the Entrypoint can be imported. Importing a file inside a Carton raises `Carton::ImportError` naming the import to use, because loading it on its own would create a second copy of the Carton's classes.
- Directories without their own `.rb` file, like Zeitwerk implicit namespaces, belong to the Carton above them, so the outermost Entrypoint wins.
- A file with no directory beside it is a Carton of one file.
- No gemspec, Gemfile, or manifest is required. A Carton may be a gem, a path gem, a gem-shaped directory, or a plain file.

## Nested Cartons

Cartons can nest in another Carton's tree, as long as they sit outside its Interior. In `billing/cartons/tax/lib/tax.rb`, `tax` is its own Carton, which `billing.rb` can `import_relative '../cartons/tax'`. Anything under `billing/lib/billing/` belongs to `billing`, so put nested Cartons beside that directory, not in it.

## Gem-shaped directories

A directory such as `components/billing/` holding `lib/billing.rb` imports by its path. The import resolves to `lib/billing.rb` as the Entrypoint and puts `lib/` on the Carton's load path, so the Carton can `require 'billing/invoice'` as a gem would.

```ruby
Billing = import_relative '../components/billing' # components/billing/lib/billing.rb
```

## Zeitwerk

A Carton's Entrypoint can run its own Zeitwerk loader, such as `Zeitwerk::Loader.for_gem`, in its own Box with its own copy of Zeitwerk.

- Constants left to autoload load in the Carton's Box, even when an importer references them first, and go through the Carton's Zeitwerk, so `on_load` callbacks and reloading work. Eager load at boot in production, as usual.
- If the app's own loader manages a directory that contains a Carton, `ignore` the Carton's Entrypoint and directory there. Otherwise the app's loader can load the Carton's files in the Main Box.
- Reloading a Carton defines new classes inside it, but importers keep whatever classes and objects they already hold.
- A loader inside a Carton may use nsfiles (Zeitwerk 2.8+, `loader.nsfile = 'ns.rb'`), so `carriers/ns.rb` defines `Carriers`. The Carton itself still needs an Entrypoint beside its directory, such as `shipping.rb` beside `shipping/`; an Entrypoint inside its directory, like `shipping/ns.rb`, is not a Carton boundary.

The [zeitwerk example](https://github.com/dtcristo/carton/tree/main/examples/zeitwerk) shows each case.
