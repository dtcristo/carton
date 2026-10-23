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

### [Exports](/guides/examples/exports/)

Export Hashes and callables, adapt legacy Ruby, and use pattern matching.

### [Tooling](/guides/examples/tooling/)

Check import and export problems with `carton check`, then generate RBS for Steep.

### [Dependency injection](/guides/examples/dependency-injection/)

Pass host adapters into a checkout Carton and test it with fakes.

### [Rack](/guides/examples/rack/)

Give each domain its own Rack app and mount them in a plain `config.ru`, with no web framework.

### [Monorepo](/guides/examples/monorepo/)

Split an app into path gems that Ruby keeps apart, with one shared lockfile, declared dependencies, and unit and integration tests.

### [Plugins](/guides/examples/plugins/)

Load plugins that need conflicting gem versions, through Dynamic Imports and a shared interface.

### [Zeitwerk](/guides/examples/zeitwerk/)

Use loaders per Box and lazy namespaces, and see why references stay stale after reload.

### [Rails](/guides/examples/rails/)

Keep Customers and Billing apart in one Rails app, using Engines with Carton-owned loaders and an explicit CLI bridge. This integration is experimental.

### [Hanami](/guides/examples/hanami/)

Keep Customers and Billing apart in one Hanami app, using slices with contracts, operations, ROM repos, views, and a CLI bridge. This integration is experimental.

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
