---
title: Examples
description: Runnable apps in the repository, from the smallest boundary to plugins, Rails, and Hanami, and how to run them.
sidebar:
  label: Overview
  order: 0
---

The repository's [examples](/guides/examples/) are small, separate programs, and CI runs every one. Each page here walks through one, with code drawn from the repository. Start with [Minimal](/guides/examples/minimal/). Similar names in different examples, such as Billing, are separate code.

| Question | Example |
| --- | --- |
| How do I draw a boundary and export a module? | [Minimal](/guides/examples/minimal/), with code for `carton check` to reject and RBS for Steep |
| What can an import return? How do I load existing Ruby? | [Exports](/guides/examples/exports/): Hashes, callables, an explicit legacy adapter, and pattern matching |
| How does a Carton use the app's database or services? | [Dependency injection](/guides/examples/dependency-injection/): a checkout with host adapters and fakes |
| How do I select gem versions without Bundler? | [Gems](/guides/examples/gems/): explicit RubyGems activation in two Cartons |
| How do Carton Bundles work across imports? | [Bundler](/guides/examples/bundler/): Gem-shaped Directories, a Transitive Carton that requires a legacy gem, and a path gem |
| How do Cartons share one app lockfile? | [Monorepo](/guides/examples/monorepo/): path gems, declared dependencies, and unit and integration tests |
| How do I host plugins with conflicting gems? | [Plugins](/guides/examples/plugins/): Dynamic Imports, a shared interface, Carton Bundles, and a contained builtin patch |
| How do autoloading and reloading interact with imports? | [Zeitwerk](/guides/examples/zeitwerk/): loaders per Box, lazy namespaces, and references that stay stale after reload |
| Can Rails itself live inside Cartons? | [Rails](/guides/examples/rails/), experimental: Customers and Billing inside Rails Engines, with Carton-owned loaders and an explicit CLI bridge |
| Can Hanami, Dry, and Rom live inside Cartons? | [Hanami](/guides/examples/hanami/): Customers and Billing in Hanami slices, with contracts, operations, ROM repos, views, and a CLI bridge |

Gems, Bundler, and Plugins all load conflicting bigdecimal versions, but teach different loading choices. Gems is the shortest version-isolation demonstration, Bundler shows setup details, and Plugins applies them.

## Run one

Use Ruby 4.0.7+ and Bundler 4.0.20+. Clone the repository, then from its root install the development bundle once and run an example by name:

```sh
bundle install
bundle exec rake example:minimal
bundle exec rake examples          # every example
```

Each `example:<name>` task installs that example's bundles, runs its `main.rb` with Boxes enabled, then runs each of its `test/**/*_test.rb` files in its own process. The first run may need network access and native build tools. After that, run an example directly:

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
```

`Carton.setup_bundle` uses gems that are already installed and never installs missing ones, so run the Rake task first on a fresh checkout.

Displayed Ruby snippets use `require 'carton'` and assume the gem is installed. The runnable checkout examples load Carton's local source instead, so they test the code you are editing.

Each Carton loads once per process. These programs run and exit, so rerun one after editing it; a long-running app restarts to pick up changed Cartons.

Unsupported and private-runtime experiments live in [spikes/](https://github.com/dtcristo/carton/tree/main/spikes), not here.
