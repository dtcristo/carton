---
title: Examples
description: Runnable apps in the repository, from the smallest boundary to plugins and Rails, and how to run them.
sidebar:
  order: 2
---

The repository's [examples](https://github.com/dtcristo/carton/tree/main/examples) are small, separate programs. Each one comments its Carton, export, and bundle boundaries. Start with minimal.

| Question | Example |
| --- | --- |
| How do I draw a boundary and export a module? | [minimal](https://github.com/dtcristo/carton/tree/main/examples/minimal), with code for `carton check` to reject and RBS for Steep |
| What can an import return? How do I load existing Ruby? | [exports](https://github.com/dtcristo/carton/tree/main/examples/exports): Hashes, callables, Bare Carton Helpers, and pattern matching |
| How do Cartons share one app lockfile? | [monorepo](https://github.com/dtcristo/carton/tree/main/examples/monorepo): path gems, declared dependencies, and unit and integration tests |
| How does a Carton use the app's database or services? | [dependency_injection](https://github.com/dtcristo/carton/tree/main/examples/dependency_injection): a checkout with host adapters and fakes |
| How do I use Carton with Rails today? | [rails_in_main](https://github.com/dtcristo/carton/tree/main/examples/rails_in_main): Rails stays in the Main Box; a plain-Ruby domain runs in a Carton |
| How do I host plugins with conflicting gems? | [plugins](https://github.com/dtcristo/carton/tree/main/examples/plugins): Dynamic Imports, a shared interface, Carton Bundles, and a contained builtin patch |
| How do I select gem versions without Bundler? | [gems](https://github.com/dtcristo/carton/tree/main/examples/gems): explicit RubyGems activation in two Cartons |
| How do Carton Bundles work across imports? | [bundler](https://github.com/dtcristo/carton/tree/main/examples/bundler): Gem-shaped Directories, a Transitive Carton, a Bare Carton gem, and a path gem |
| How do autoloading and reloading interact with imports? | [zeitwerk](https://github.com/dtcristo/carton/tree/main/examples/zeitwerk): loaders per Box, lazy namespaces, and references that stay stale after reload |
| Can Rails itself live inside Cartons? | [rails_in_cartons](https://github.com/dtcristo/carton/tree/main/examples/rails_in_cartons), experimental: shared framework classes and explicit registration |

## Run one

Clone the repository, then from its root install the development bundle once and run an example by name:

```sh
bundle install
bundle exec rake example:minimal
```

Each `example:<name>` task installs that example's bundles, runs its `main.rb` with Boxes enabled, then runs its tests. After that, run it directly:

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
```

`Carton.setup_bundle` uses gems that are already installed and never installs missing ones, so run the Rake task first on a fresh checkout.

Each Carton loads once per process. These programs run and exit, so rerun one after editing it; a long-running app restarts to pick up changed Cartons.
