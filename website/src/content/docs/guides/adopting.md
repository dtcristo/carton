---
title: Adopting Carton
description: Bring Carton into an existing app one Carton at a time, run it with Boxes enabled, and roll back to plain require.
sidebar:
  order: 9
---

Carton can enter an existing app one domain at a time. Each step below leaves the app working, and the last one undoes them all. Read [Status](/start/status/#before-production) first: Carton and `Ruby::Box` are both experimental.

## 1. Run the app with Boxes enabled

Before adding a Carton, run the app and its test suite with `RUBY_BOX=1` and no other change. Box support is new in Ruby, so check that your gems work with it enabled; Ruby also prints an experimental warning to stderr. Fix or note failures here, before any Carton is involved.

## 2. Extract one leaf domain

Pick a domain that nothing else in the app reaches into, such as tax rules or a vendor client. Make it a path gem whose gemspec depends on `carton`, with an Entrypoint that requires `carton` and exports its root module:

```
cartons/tax/tax.gemspec
cartons/tax/lib/tax.rb       # the Entrypoint: export Tax
cartons/tax/lib/tax/rates.rb # the Interior
```

```ruby title="Gemfile"
gem 'carton'
gem 'tax', path: 'cartons/tax'
```

Import it by name from the Main Box, where the app already runs Bundler setup:

```ruby
require 'carton'

Tax = import 'tax' # runs cartons/tax/lib/tax.rb in its own Box
```

Code that called `Tax` before keeps working. Code that reached a constant `Tax` keeps private now raises `NameError`, which shows where the boundary was crossed. The [Monorepo example](/guides/examples/monorepo/) has three domains in this shape, with tests.

## 3. Adapt code you cannot change

Legacy files and gems without an `export` stay ordinary Ruby. Give each a distinct adapter Entrypoint that requires it and explicitly exports the value Importers need:

```ruby
# cartons/vendor_sdk.rb: an adapter Carton for a gem with no export
require 'vendor_sdk' # loads, with its core extensions, inside this Box

export VendorSDK::Client
```

The gem's monkey patches to builtin classes stay in the adapter's Box. The [Exports example](/guides/examples/exports/) includes an adapter for an existing file.

## 4. Check boundaries in CI

Add [`carton check`](/reference/cli/check/) to CI. It reports what the runtime cannot catch, such as Second Copies from plain `require` and Undeclared Gems. The command comes from the `carton-tools` gem:

```ruby title="Gemfile"
gem 'carton-tools', group: %i[development test]
```

```sh
bundle exec carton check main.rb
```

Each problem prints as `file:line:column: level: message [rule]`, and `--format json` gives the same problems with their rule IDs for CI annotations. Once the app is clean, add `--strict` so warnings fail the build too. If you commit RBS from [`carton rbs`](/reference/cli/rbs/), `carton rbs --check` fails CI when it is stale. [`carton graph`](/reference/cli/graph/) and [`carton why`](/reference/cli/why/) show which Cartons import which as the app grows.

## 5. Grow to tens of Cartons

Extract further domains the same way, inner leaves first. Each Carton adds startup time and memory, so split by domain, not by file: aim for tens of Cartons, not hundreds. [Status](/start/status/#cost-per-carton) has the current numbers.

## 6. Roll back

Carton files are plain Ruby. Under plain `require`, `export` returns its argument and does nothing else, so where an Export's name matches its binding, replacing `Tax = import 'tax'` with `require 'tax'` restores the old shape. An adapter that exports another name needs an explicit binding, such as `VendorClient = VendorSDK::Client` after `require 'vendor_sdk'`, and a Carton with its own bundle needs its gems moved into the app's Gemfile. Keep `require 'carton'` loaded so `export` stays defined, and drop `RUBY_BOX=1` once no `import` remains.

## Operations

- **Warning.** Every process run with `RUBY_BOX=1` prints `warning: Ruby::Box is experimental, and the behavior may change in the future!` to stderr.
- **Every entry point.** Set `RUBY_BOX=1` wherever the app starts: servers, job workers, Rake tasks, consoles, CI, and the environment of your Dockerfile or Procfile. An `import` without it raises `Carton::ImportError`.
- **Native extensions.** Ruby copies a native extension to a temporary file for each Box that loads it, so memory and disk use grow with every Carton that loads the extension. Running with a read-only temporary directory is untested.
- **Process-global state.** Boxes isolate definitions and load state, not the process. `ENV` (see [Bundler](/guides/bundler/#env)), the working directory, signal traps, `at_exit` hooks, threads, and file descriptors are shared by every Box: a `trap` in a Carton replaces the app's handler for that signal, and `Dir.chdir` in a Carton moves the whole process. Objects passed between Cartons are shared too; see [Sharing classes and services](/guides/sharing-classes/).
- **Servers and boot caches.** The [Rails](/guides/examples/rails/) and [Hanami](/guides/examples/hanami/) examples test HTTP requests through Puma. Forking servers, preloading, and Bootsnap are untested with Carton.
