# TODO

Ordered by priority within each section.

## Library

- Raise a Carton error explaining `RUBY_BOX=1` when Boxes are disabled, instead of the raw `Ruby::Box` error from `Carton::Box#initialize`.
- Include the paths Carton tried in missing-Import `LoadError` messages.
- Add `keys`, `to_h`, and a readable `inspect` (e.g. `#<Carton::Exports PI, add>`) to `Carton::Exports`.
- Ship `exe/carton` that sets `RUBY_BOX=1` and execs Ruby, so `carton main.rb` just works.
- Consider an opt-in guard that warns when a Carton reopens a class another Carton exported. A `TracePoint(:class)` in the Main Box sees `class Foo` reopens in every Box, and Carton knows which Carton exported each class; it would not catch `class_eval` or `define_method`.
- Decide whether gem Cartons should key Imports by gem instead of Entrypoint path, so `import 'gem'` and `import 'gem/sub'` share one Box.
- Cache rebuilt specs per caller bundle: strict gem Cartons rebuild every locked spec from YAML on each first import, which grows with bundle size.
- Decide what non-gem Cartons (plain `import_relative` directories) should see from the caller's bundle; today they see nothing unless they call `setup_bundle`.
- Consider a fresh-Import escape hatch (e.g. `import(path, fresh: true)`) if tests or tools need an isolated copy of a shared Carton.
- Revisit whether `import` should always return a `Carton::Exports` with a `default` accessor, or whether the current duck-typed return values fit better long term.
- Consider a small helper for the `register` pattern in `examples/rails_in_cartons` if more framework integrations need it.
- Test that the gem builds, installs into a clean gem home, and can be required and imported.

## Tooling

Packages as gems, with these checks, are proposed in [dtcristo/carton#32](https://github.com/dtcristo/carton/issues/32).

- Prototype a Prism-based `carton check` that finds root-level `import` and `export` calls and builds a static dependency graph without evaluating code.
- Report cycles, missing import targets, dead imports, and unused exports.
- Report imports that a gem Carton's gemspec does not declare (see `examples/monorepo`). At runtime a gem Carton sees the caller's whole lockfile, so this is the cheapest way to enforce package dependencies.

## Upstream

See [upstream.md](internals/upstream.md) for detail.

- Post the Bundler activation API proposal ([dtcristo/carton#16](https://github.com/dtcristo/carton/issues/16)) upstream and comment on [Ruby #22275](https://bugs.ruby-lang.org/issues/22275) with Carton's use case.
- Post the template Box proposal ([dtcristo/carton#25](https://github.com/dtcristo/carton/issues/25)) to bugs.ruby-lang.org: official template Box support, framed as requirements derived from how Box copy-on-write works, leaving Master clean.
- Send a one-line fix for `doc/language/box.md`, which still says Main is created at the end of bootstrap.
- Idea, low odds: constant binding in patterns (`import(path) => { Name: }`). Matz limits pattern targets to locals ([#18408](https://bugs.ruby-lang.org/issues/18408)); see [constant-binding-patterns.md](internals/constant-binding-patterns.md). `export_default` and plain assignment already cover it.

## Docs

- Expand the Rails examples into a guide: passing records into Cartons, testing Cartons in a Rails app, and reloading (Cartons last for the life of the process).
