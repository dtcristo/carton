---
title: Status
description: Carton's current limitations, experimental integrations, and possible future features.
sidebar:
  order: 2
---

Carton provides explicit imports and exports, per-Carton gem versions, and gem-shaped distribution. It remains experimental, as does `Ruby::Box`. Use Ruby 4.0.7 or later and, with Bundler, Bundler 4.0.20 or later.

## Cost per Carton

A plain Carton costs about 60 ms and 2.4 MB in the [current measurements](https://github.com/dtcristo/carton/blob/main/docs/performance.md), most of it `Ruby::Box.new`. Aim for tens of Cartons rather than hundreds. Gem Cartons cost more because they also load RubyGems specifications into their Boxes.

Cheaper Boxes, Template Boxes ([#25](https://github.com/dtcristo/carton/issues/25)), and Boxes started from a resolved load path ([Ruby #22275](https://bugs.ruby-lang.org/issues/22275)) could reduce that cost. These require upstream Ruby support.

## Shared classes and objects

Exports are shared objects. Reopening an exported class or changing shared state affects every Importer. `carton check` warns about class/module definitions through directly followed Imports, but adds no runtime guard and cannot follow aliases or dynamic mutations. See [Sharing classes and services](/guides/sharing-classes/).

## Dependency enforcement

A Gem Carton's gemspec declares its dependencies, and `carton check` reports Undeclared Gems. At runtime, however, it receives the Importer's whole lockfile. Restricting it to declared dependencies remains deferred while Ruby's resolved-load-path proposal develops.

## Static analysis

`carton check` cannot follow every reflective or generated import. `carton rbs` leaves Exports it cannot infer as `untyped`, and RBS has one global namespace for all Cartons. See [Types and checks](/guides/types-and-checks/) for the supported checks and type generation.

## Rails integration

The experimental [Rails example](/guides/examples/rails/) runs Customers and Billing as isolated Engines, with Carton-owned loaders and an explicit CLI bridge. Reloading remains unsupported. Domain Cartons load their own Active Support extensions, and the example does not establish compatibility with arbitrary Rails features or third-party Engines.

## Experimental Ruby Boxes

Ruby requires `RUBY_BOX=1` to enable Boxes. Box isolates definitions and load state, not shared objects, and is not a security sandbox.

## Possible future features

Public sub-entrypoints could let large Cartons expose lazy parts of their Interior. Today only the Entrypoint can be imported. An import graph and a baseline file are also possible tooling additions. These are design options, not a committed roadmap.

Unsupported and private-runtime experiments live in [spikes/](https://github.com/dtcristo/carton/tree/main/spikes), including shared-gem loading and Rails reloading. They do not change the supported runtime's guarantees.
