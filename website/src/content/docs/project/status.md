---
title: Status
description: What a package system needs, and how close Carton is to each piece.
sidebar:
  order: 2
---

Carton is experimental, and so is `Ruby::Box`. It targets Ruby 4.0.7 or later and, with Bundler, Bundler 4.0.20 or later.

| Need | Status |
| --- | --- |
| A private interior per Carton | Done. Only an Entrypoint can be imported, only exports cross, and `private_constant` hides the rest. |
| Imports bound where they are used | Done. `import` returns a value and defines nothing in the importer. |
| Gem versions per Carton | Done. A Carton that calls `Carton.setup_bundle` gets its own bundle, and Gem Cartons get the importer's versions. A shared Carton keeps its First Importer's versions. |
| Contained side effects | Partly. Patches to builtins stay in their Carton, but exported classes are shared and can be reopened. |
| Declared dependencies | Partly. A Gem Carton's gemspec declares them and `carton check` reports Undeclared Gems, but the runtime gives it the importer's whole lockfile. |
| Graph tooling | Partly. `carton check` and `carton rbs` exist; a dependency graph and a baseline file do not. |
| Distribution | Done by design. A Carton is gem-shaped, and each Carton in a monorepo is a path gem ([#32](https://github.com/dtcristo/carton/issues/32)). |
| Public sub-entrypoints | Missing. Only the Entrypoint can be imported. |
| Cheap enough for many Cartons | Missing. About 60 ms and 2.4 MB per Carton, most of it `Ruby::Box.new`, so tens of Cartons, not hundreds ([performance numbers](https://github.com/dtcristo/carton/blob/main/docs/performance.md)). |
| Works with Rails | Partly. [Rails in the Main Box](/guides/rails/) works; Rails inside Cartons has no supported reloading or Rails CLI, and domain Cartons load Active Support's core extensions themselves. |
| On by default | Missing. Ruby needs `RUBY_BOX=1`, and `Ruby::Box` is experimental. |

The model fits. The biggest gaps are cost, Rails inside Cartons, and Box's experimental status. Ruby itself would close most of the cost gap, through cheaper Boxes, Template Boxes ([#25](https://github.com/dtcristo/carton/issues/25)), and Boxes started from a resolved load path ([Ruby #22275](https://bugs.ruby-lang.org/issues/22275)).

Unsupported and private-runtime experiments live in [spikes/](https://github.com/dtcristo/carton/tree/main/spikes). The [Master prelude spike](https://github.com/dtcristo/carton/tree/main/spikes/master_prelude) changes Ruby's internal copy source; the [Rails reloading spike](https://github.com/dtcristo/carton/tree/main/spikes/rails_reloading) reads and changes private Carton state. Both Rails integrations remain [examples](https://github.com/dtcristo/carton/tree/main/examples), with Rails in the Main Box the recommended setup today.
