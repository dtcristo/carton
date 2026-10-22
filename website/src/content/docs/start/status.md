---
title: Status
description: What must change before Carton is ready for production, plus its current limitations and possible future features.
sidebar:
  order: 2
---

Carton provides explicit imports and exports, per-Carton gem versions, and gem-shaped distribution. It remains experimental, as does `Ruby::Box`. Use Ruby 4.0.7 or later and, with Bundler, Bundler 4.0.20 or later.

## Before production

A team should not rely on Carton in production until these change:

- **`Ruby::Box` leaves experimental status.** Upstream Ruby. Every process run with `RUBY_BOX=1` prints Ruby's experimental warning, and Box behavior may change between Ruby releases.
- **Cheaper Boxes.** Upstream Ruby. Template Boxes ([#25](https://github.com/dtcristo/carton/issues/25)) or Boxes started from a resolved load path ([Ruby #22275](https://bugs.ruby-lang.org/issues/22275)) would lower the [cost per Carton](#cost-per-carton).
- **Rails reloading.** Carton. Rails apps restart on change. A [reloading spike](https://github.com/dtcristo/carton/tree/main/spikes/rails_reloading) rebuilds changed Cartons through private hooks, but the runtime has no reload interface.
- **Runtime dependency enforcement.** Carton, waiting on Ruby #22275. A Gem Carton sees its Importer's whole lockfile at runtime; see [Dependency enforcement](#dependency-enforcement).

To try Carton in an existing app now, follow [Adopting Carton](/guides/adopting/), which also covers [operations](/guides/adopting/#operations).

## Cost per Carton

A plain Carton costs about 60 ms and 2.4 MB in the [current measurements](https://github.com/dtcristo/carton/blob/main/docs/performance.md), most of it `Ruby::Box.new`. Aim for tens of Cartons rather than hundreds. Gem Cartons cost more because they also load RubyGems specifications into their Boxes.

## Shared classes and objects

Exports are shared objects. Reopening an exported class or changing shared state affects every Importer. `carton check` warns about class/module definitions through directly followed Imports, but adds no runtime guard and cannot follow aliases or dynamic mutations. See [Sharing classes and services](/guides/sharing-classes/) and [what a Box does not isolate](/start/why-carton/#what-a-box-does-not-isolate).

## Dependency enforcement

A Gem Carton's gemspec declares its dependencies, and `carton check` reports Undeclared Gems. At runtime, however, it receives the Importer's whole lockfile. Restricting it to declared dependencies remains deferred while Ruby's resolved-load-path proposal develops.

## Static analysis

`carton check` cannot follow every reflective or generated import. `carton rbs` leaves Exports it cannot infer as `untyped`, and RBS has one global namespace for all Cartons. See [Types and checks](/guides/types-and-checks/) for the supported checks and type generation.

## Rails integration

The experimental [Rails example](/guides/examples/rails/) runs Customers and Billing as isolated Engines, with Carton-owned loaders and an explicit CLI bridge. Domain Cartons load their own Active Support extensions, and the example does not establish compatibility with arbitrary Rails features or third-party Engines.

## Ruby bugs

On Ruby 4.0.7, changing only a builtin method's visibility (such as `protected :upcase` on `String`) leaks from a Box to every other Box ([reproduction](https://github.com/dtcristo/carton/blob/main/spikes/shared_gems/09_visibility_leak.rb)). This is an upstream Ruby bug, not a Carton limitation.

## Possible future features

Public sub-entrypoints could let large Cartons expose lazy parts of their Interior. Today only the Entrypoint can be imported. An import graph and a baseline file are also possible tooling additions. These are design options, not a committed roadmap.

Unsupported and private-runtime experiments live in [spikes/](https://github.com/dtcristo/carton/tree/main/spikes), including shared-gem loading and Rails reloading. They do not change the supported runtime's guarantees.
