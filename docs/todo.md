# TODO

Ordered by priority within each section. Proposed next steps after 0.2.0
(a `carton` CLI, RBS and Tapioca types, static checks, strict gem Cartons) are
in [dtcristo/carton#38](https://github.com/dtcristo/carton/issues/38).

## Library

- Include the paths Carton tried in missing-Import `LoadError` messages.
- Add `keys`, `to_h`, and a readable `inspect` (e.g. `#<Carton::Exports PI, add>`) to `Carton::Exports`.
- Consider an opt-in guard that warns when a Carton reopens a class another Carton exported. A `TracePoint(:class)` in the Main Box sees `class Foo` reopens in every Box, and Carton knows which Carton exported each class; it would not catch `class_eval` or `define_method`.
- If large Cartons need lazy parts, let a Carton declare public sub-entrypoints that can be imported, like the `exports` field in Node's `package.json`. Today a file inside a Carton cannot be imported.
- Cache rebuilt specs per caller bundle: strict gem Cartons rebuild every locked spec from YAML on each first import, which grows with bundle size.
- Decide what non-gem Cartons (plain `import_relative` directories) should see from the caller's bundle; today they see nothing unless they call `setup_bundle`.
- Consider a fresh-Import escape hatch (e.g. `import(path, fresh: true)`) if tests or tools need an isolated copy of a shared Carton.
- Consider a small helper for the `register` pattern in `examples/rails_in_cartons` if more framework integrations need it.
- Test that the gem builds, installs into a clean gem home, and can be required and imported.

## Tooling

`carton rbs` and `carton check` exist; the rest of [dtcristo/carton#38](https://github.com/dtcristo/carton/issues/38) is still open. Packages as gems are proposed in [dtcristo/carton#32](https://github.com/dtcristo/carton/issues/32).

- `carton check`: report unused exports and dead imports.
- `carton check`: report imports that a gem Carton's gemspec does not declare (see `examples/monorepo`). At runtime a gem Carton sees the caller's whole lockfile, so this is the cheapest way to enforce package dependencies.
- `carton check`: report gem versions in a Carton's own `Gemfile.lock` that disagree with the app's.
- `carton rbs`: read exported top-level method types from a Carton's own RBS, not only rbs-inline `#:` annotations.
- `carton rbs`: optionally write Steepfile targets, one per Carton, so Cartons' internal constants cannot clash in RBS's single namespace.
- Sorbet through a Tapioca DSL compiler, if `tapioca dsl` works under `RUBY_BOX=1`.

## Upstream

See [upstream.md](internals/upstream.md) for detail.

- Post the Bundler activation API proposal ([dtcristo/carton#16](https://github.com/dtcristo/carton/issues/16)) upstream and comment on [Ruby #22275](https://bugs.ruby-lang.org/issues/22275) with Carton's use case.
- Post the template Box proposal ([dtcristo/carton#25](https://github.com/dtcristo/carton/issues/25)) to bugs.ruby-lang.org: official template Box support, framed as requirements derived from how Box copy-on-write works, leaving Master clean.
- Send a one-line fix for `doc/language/box.md`, which still says Main is created at the end of bootstrap.
- Idea, low odds: constant binding in patterns (`import(path) => { Name: }`). Matz limits pattern targets to locals ([#18408](https://bugs.ruby-lang.org/issues/18408)); see [constant-binding-patterns.md](internals/constant-binding-patterns.md). `export_default` and plain assignment already cover it.

## Docs

- Expand the Rails examples into a guide: passing records into Cartons, testing Cartons in a Rails app, and reloading (Cartons last for the life of the process).
