---
title: Why Carton
description: Why a growing Ruby app needs runtime boundaries, how Carton compares with Bundler, Packwerk, and separate services, and what Ruby::Box does not isolate.
sidebar:
  order: 1
---

A boundary is a line code can't cross. Ruby apps draw boundaries with folders and namespaces. Ruby ignores them. Every file loads into one namespace: any code can reach any constant, a patch to a builtin class applies everywhere, and one Gemfile fixes one version of each gem for the whole process. Gems and Bundler share code and pick versions, but inside an app, a boundary is only a convention.

## What goes wrong

In a small app, that openness is freedom. In a big one, the costs land on teams who never made the change:

- **Internals become API.** Shipping calls `Billing::Ledger` because nothing stops it, and now Billing can't change its ledger without breaking Shipping.
- **Patches act at a distance.** Billing redefines `Integer#to_s` to format money, and a Shipping label prints `Box $0.03 of $0.04`.
- **Upgrades are all or nothing.** Billing needs Faraday 2, Shipping's SDK pins Faraday 1, and the one Gemfile can hold only one.

The usual answers are conventions, static checks, or separate services. Conventions erode, static checks miss what they can't parse, and services turn method calls into network calls with serialization and separate deploys.

## What Carton does

Carton makes boundaries real. Each Carton is a boundary that only its export can cross. It has its own dependencies and runs in a separate [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html), so Ruby enforces the boundary at runtime:

- other Cartons reach **only what a Carton exports**;
- **monkey patches to builtin classes**, such as `String#blank?`, stay in the Carton that makes them;
- two Cartons can use **different versions of the same gem**.

Inside a Carton, Ruby stays as open as ever. Between Cartons, calls are still method calls in one process. And because a Carton is shaped like a gem, one that grows a gemspec can leave the app without changing its Importers.

## Compared with Bundler, Packwerk, and services

| Capability | Bundler | [Packwerk](https://github.com/Shopify/packwerk) | Separate services | Carton |
| --- | --- | --- | --- | --- |
| Boundaries | None | Static checks | The network | Runtime enforcement |
| Private code | None | No privacy checks | Service API | Explicit Export |
| Lookups by name (`const_get`, `constantize`) | Unchecked | Unchecked | Cannot cross | Enforced by the Box |
| Gem versions | One per app | One per app | One per service | One per Carton |
| Builtin patches | Global | Global | Per service | Per Carton |
| Calls between parts | Method calls | Method calls | Network calls and serialization | Method calls |
| Distribution | Gem | App-local pack | Deployed service | Gem-shaped Carton |

Only a Carton's Export crosses its boundary. When that Export is a module, Ruby's `private_constant` hides selected constants within it. Packwerk removed its privacy checks in version 3.0.

Rails Engines and plain path gems split code into directories and gemspecs, but still load into one namespace: any file can reach an Engine's constants, a patch in one gem applies everywhere, and the app's Gemfile picks one version of each gem. A Carton can be a path gem or wrap an Engine, as the [Monorepo](/guides/examples/monorepo/) and [Rails](/guides/examples/rails/) examples do; the Box adds the boundary.

Static checks only see what they can parse. Packwerk's authors note that a package with zero violations "may actually crash with name errors when its code is executed" ([A Packwerk Retrospective](https://shopify.engineering/a-packwerk-retrospective)). A Carton's boundary is the Box it runs in, so Ruby holds it even for code no tool can follow. `carton check` adds what the runtime cannot enforce, such as Second Copies from plain `require` and Undeclared Gems, before the code runs.

## What a Box does not isolate

- **Shared objects.** Classes and objects a Carton exports are shared, not copied, so reopening an exported class or changing a shared object affects every Importer. See [Sharing classes and services](/guides/sharing-classes/).
- **Plain `require`.** A `require` of a Carton's files loads a Second Copy outside its boundary, which `carton check` reports.
- **Process lifetime.** Each Carton loads once per process: its state lasts as long as the process, and its First Importer fixes its gem versions.
- **Process-global state.** `ENV`, the working directory, signal traps, `at_exit` hooks, threads, and file descriptors belong to the process. See [Operations](/guides/adopting/#operations).
- **Security.** Box isolates definitions and load state, not objects. It is not a sandbox.

## Where it fits today

- **Upgrade a gem in one domain without upgrading the app.** Each Carton can set up its own bundle; see [A Carton's own bundle](/guides/bundler/#a-cartons-own-bundle).
- **Keep a vendor SDK's core extensions out of the rest of the app.** Require the SDK in an adapter Carton and export only the client you need, as the [Exports](/guides/examples/exports/) example's adapter does.
- **Load plugins that need conflicting gem versions**, which plain Ruby cannot load together; see the [Plugins](/guides/examples/plugins/) example.
- **Mount domain Cartons in a web app.** Each Carton can export a Rack app, as in the [Rack](/guides/examples/rack/) example. Rails and Hanami work as experimental integrations; see the [Rails](/guides/examples/rails/) and [Hanami](/guides/examples/hanami/) examples.

Each Carton has a startup and memory cost, so aim for tens of Cartons, not hundreds; [Status](/guides/status/) has the numbers and what must change before production. [Adopting Carton](/guides/adopting/) shows how to start in an existing app.
