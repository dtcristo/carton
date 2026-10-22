---
title: Examples
description: Runnable apps in the repository, from the smallest boundary to plugins, Rails, and Hanami, and how to run them.
sidebar:
  label: Overview
  order: 0
---

The repository's examples are small, separate programs, and CI runs every one. Each page walks through one, with code drawn from the repository. Start with [Minimal](/guides/examples/minimal/). Similar names in different examples, such as Billing, are separate code.

## Examples

### [Minimal](/guides/examples/minimal/)

Draw a boundary, export a module, and import it from an app.

### [Tooling](/guides/examples/tooling/)

Check import and export problems with `carton check`, then generate RBS for Steep.

### [Exports](/guides/examples/exports/)

Export Hashes and callables, adapt legacy Ruby, and use pattern matching.

### [Dependency injection](/guides/examples/dependency-injection/)

Pass host adapters into a checkout Carton and test it with fakes.

### [Bundler](/guides/examples/bundler/)

Set up Carton Bundles across imports, including a Transitive Carton and a path gem.

### [Monorepo](/guides/examples/monorepo/)

Share one app lockfile across path gems with declared dependencies and unit and integration tests.

### [Plugins](/guides/examples/plugins/)

Load plugins with conflicting gem versions through Dynamic Imports and a shared interface.

### [Zeitwerk](/guides/examples/zeitwerk/)

Use loaders per Box and lazy namespaces, and see why references stay stale after reload.

### [Rails](/guides/examples/rails/)

Run Customers and Billing inside Rails Engines with Carton-owned loaders and an explicit CLI bridge. This integration is experimental.

### [Hanami](/guides/examples/hanami/)

Run Customers and Billing in Hanami slices with contracts, operations, ROM repos, views, and a CLI bridge.

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
