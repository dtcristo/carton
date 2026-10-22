---
title: Status
description: What a package system needs, and how close Carton is to each piece.
sidebar:
  order: 2
---

Carton is experimental, and so is `Ruby::Box`. It targets Ruby 4.0.7 or later and, with Bundler, Bundler 4.0.20 or later.

| Need | Status |
| --- | --- |
| A private Interior per Carton | Done. Only an Entrypoint can be imported, it must call `export` exactly once, only that value crosses, and `private_constant` hides the rest. |
| Imports bound where they are used | Done. `import` returns a value and defines nothing in the Importer. |
| Gem versions per Carton | Done. A Carton that calls `Carton.setup_bundle` gets its own bundle, and Gem Cartons get the Importer's versions. A shared Carton keeps its First Importer's versions. |
| Contained side effects | Partly. Patches to builtins stay in their Carton, but exported classes are shared and can be reopened. `carton check` warns about class/module definitions through directly followed Imports; it adds no runtime guard. |
| Declared dependencies | Partly. A Gem Carton's gemspec declares them and `carton check` reports Undeclared Gems, but the runtime gives it the Importer's whole lockfile. |
| Graph tooling | Partly. `carton check` and `carton rbs` exist; an import graph and a baseline file do not. |
| Distribution | Done by design. A Carton is gem-shaped, and each Carton in a monorepo is a path gem ([#32](https://github.com/dtcristo/carton/issues/32)). |
| Public sub-entrypoints | Missing. Only the Entrypoint can be imported. |
| Cheap enough for many Cartons | Missing. About 60 ms and 2.4 MB per Carton, most of it `Ruby::Box.new`, so tens of Cartons, not hundreds ([performance numbers](https://github.com/dtcristo/carton/blob/main/docs/performance.md)). |
| Works with Rails | Partly. The experimental [Rails example](/guides/rails/) implements Customers and Billing as isolated Engines, with Carton-owned loaders and an example-local `bin/rails` bridge. Rails reloading remains unsupported; domain Cartons load their own Active Support extensions. |
| On by default | Missing. Ruby needs `RUBY_BOX=1`, and `Ruby::Box` is experimental. |

The model fits. The biggest gaps are cost, Rails support, and Box's experimental status. Ruby itself would close most of the cost gap, through cheaper Boxes, Template Boxes ([#25](https://github.com/dtcristo/carton/issues/25)), and Boxes started from a resolved load path ([Ruby #22275](https://bugs.ruby-lang.org/issues/22275)).

Unsupported and private-runtime experiments live in [spikes/](https://github.com/dtcristo/carton/tree/main/spikes). The [Master prelude spike](https://github.com/dtcristo/carton/tree/main/spikes/master_prelude) changes Ruby's internal copy source; the [Rails reloading spike](https://github.com/dtcristo/carton/tree/main/spikes/rails_reloading) reads and changes private Carton state. The [Rails example](/guides/examples/rails/) uses public Ruby APIs and remains an experimental integration.
