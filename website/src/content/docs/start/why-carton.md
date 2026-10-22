---
title: Why Carton
description: How Carton's imports, exports, and runtime boundaries compare with Bundler and Packwerk, and what Ruby::Box does not isolate.
sidebar:
  order: 1
---

Ruby has gems to share code and Bundler to pick their versions, but nothing inside an app draws a boundary. Every file loads into one namespace: any code can reach any constant, a monkey patch applies everywhere, and one Gemfile fixes one version of each gem for the whole process. A boundary is a convention.

Split your app into Cartons with explicit imports and exports. Each has its own dependencies and runs in a separate [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html), so Ruby enforces the boundaries at runtime:

- other Cartons reach **only what a Carton exports**;
- **monkey patches to builtin classes**, such as `String#blank?`, stay in the Carton that makes them;
- two Cartons can use **different versions of the same gem**.

## Compared with Bundler and Packwerk

| Capability | Bundler | [Packwerk](https://github.com/Shopify/packwerk) | Carton |
| --- | --- | --- | --- |
| App boundaries | None | Static checks | Runtime enforcement |
| Private code | None | No privacy checks | Explicit Export |
| Dynamic constants | No boundary | Not checked | Inside the boundary |
| Gem versions | One per app | One per app | One per Carton |
| Builtin patches | Global | Global | Per Carton |
| Distribution | Gem | App-local pack | Gem-shaped Carton |

Only a Carton's Export crosses its boundary. When that Export is a module, Ruby's `private_constant` hides selected constants within it. Packwerk removed its privacy checks in version 3.0.

Carton also provides static checks through `carton check`. Its gem-shaped Entrypoint and Interior let a Carton become a gem without changing how Importers use it.

Static checks only see what they can parse. Packwerk's authors note that a package with zero violations "may actually crash with name errors when its code is executed" ([A Packwerk Retrospective](https://shopify.engineering/a-packwerk-retrospective)). A Carton's boundary is the Box it runs in, so Ruby holds it even for code no tool can follow. `carton check` adds what the runtime cannot enforce, such as Second Copies from plain `require` and Undeclared Gems, before the code runs.

## What a Box does not isolate

- **Shared objects.** Classes and objects a Carton exports are shared, not copied, so reopening an exported class or changing a shared object affects every Importer. See [Sharing classes and services](/guides/sharing-classes/).
- **Plain `require`.** A `require` of a Carton's files loads a Second Copy outside its boundary, which `carton check` reports.
- **Process lifetime.** Each Carton loads once per process: its state lasts as long as the process, and its First Importer fixes its gem versions.
- **Security.** Box isolates definitions and load state, not objects. It is not a sandbox.

## Where it fits today

- **The domains of an app or a monorepo**, as tens of Cartons. See the [Monorepo](/guides/examples/monorepo/) example.
- **Plugin hosts whose plugins need conflicting gem versions**, which plain Ruby cannot load together; see [Plugins](/guides/examples/plugins/).
- **Rails** is an experimental integration direction ([Rails example](/guides/examples/rails/)). It uses namespaced Rails Engines, explicit namespace registration, Carton-owned loaders, and an example-local Rails CLI bridge. Rails reloading remains unsupported. A separate [reloading spike](https://github.com/dtcristo/carton/tree/main/spikes/rails_reloading) explores private runtime hooks; the ordinary example does not use them.
- **Not yet file by file.** Each Carton costs about 60 ms and 2.4 MB, most of it `Ruby::Box.new`, so aim for tens of Cartons, not hundreds.
