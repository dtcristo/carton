# TODO

Ordered by priority within each section.

## Library

- Spike Rails inside Cartons, the biggest gap to the North Star in [AGENTS.md](../AGENTS.md): reload changed domain Cartons by evicting them and the Cartons that import them from the import cache, add a Carton-aware `rails console`, and measure what Active Support's core extensions cost each domain Box.
- Consider an opt-in guard that warns when a Carton reopens a class another Carton exported. A `TracePoint(:class)` in the Main Box sees `class Foo` reopens in every Box, and Carton knows which Carton exported each class; it would not catch `class_eval` or `define_method`.
- If large Cartons need lazy parts, let a Carton declare public sub-entrypoints that can be imported, like the `exports` field in Node's `package.json`. Today a file inside a Carton cannot be imported.
- Stop loading Psych into each gem Carton's Box: rebuilding specs from YAML costs about 86 ms of a gem Carton's 195 ms ([performance.md](performance.md)). Avoid a `Marshal` round trip, which RubyGems had to special-case across Boxes. If Boxes can start from a resolved load path ([Ruby #22275](https://bugs.ruby-lang.org/issues/22275)), spec rebuilding goes away entirely.
- Drop the autoload `require` workaround in `Carton::Box` once the minimum Ruby includes [ruby/ruby#18534](https://github.com/ruby/ruby/pull/18534) ([Bug #21830](https://bugs.ruby-lang.org/issues/21830)).
- Parked: strict gem Cartons, which load only a gem Carton's declared dependencies at runtime. Wait for [Ruby #22275](https://bugs.ruby-lang.org/issues/22275) to settle whether Boxes get resolved load paths, which would make this a load-path choice instead of more Bundler internals. `carton check` already reports undeclared gems.
- Decide what non-gem Cartons (plain `import_relative` directories) should see from the caller's bundle; today they see nothing unless they call `setup_bundle`.
- Consider a fresh-Import escape hatch (e.g. `import(path, fresh: true)`) if tests or tools need an isolated copy of a shared Carton.
- Consider a small helper for the `register` pattern in `examples/rails_in_cartons` if more framework integrations need it.
- Test that the gem builds, installs into a clean gem home, and can be required and imported.

## Tooling

`carton rbs` and `carton check` exist; the rest of [dtcristo/carton#38](https://github.com/dtcristo/carton/issues/38) is still open. Packages as gems are proposed in [dtcristo/carton#32](https://github.com/dtcristo/carton/issues/32).

- `carton check`: report unused exports and dead imports.
- `carton check`: resolve imports inside a Carton that calls `setup_bundle` against its own `Gemfile.lock`, then report a gem Carton shared by importers whose lockfiles lock its dependencies at different versions (a runtime `Carton::ImportError` today).
- `carton rbs`: read exported top-level method types from a Carton's own RBS, not only rbs-inline `#:` annotations.
- `carton rbs`: optionally write Steepfile targets, one per Carton, so Cartons' internal constants cannot clash in RBS's single namespace.
- Sorbet through a Tapioca DSL compiler, if `tapioca dsl` works under `RUBY_BOX=1`.

## Upstream

See [upstream.md](internals/upstream.md) for detail.

- Measure and report `Ruby::Box.new` cost (about 55 ms and 2.2 MB per Box on 4.0.7, see [performance.md](performance.md)), the floor for every import.
- Comment on [Ruby #22275](https://bugs.ruby-lang.org/issues/22275) with Carton's use case, supporting Boxes created from a resolved load path (proposed there on 2026-09-25), and reframe [dtcristo/carton#16](https://github.com/dtcristo/carton/issues/16) around it.
- Post the template Box proposal ([dtcristo/carton#25](https://github.com/dtcristo/carton/issues/25)) to bugs.ruby-lang.org: official template Box support, framed as requirements derived from how Box copy-on-write works, leaving Master clean.
- Send a one-line fix for `doc/language/box.md`, which still says Main is created at the end of bootstrap.
- Idea, low odds: constant binding in patterns (`import(path) => { Name: }`). Matz limits pattern targets to locals ([#18408](https://bugs.ruby-lang.org/issues/18408)); see [constant-binding-patterns.md](internals/constant-binding-patterns.md). `export_default` and plain assignment already cover it.

## Docs

- Expand the Rails examples into a guide: passing records into Cartons and testing Cartons in a Rails app. For reloading, the Rails examples document restarting on change; Zeitwerk reloading inside a Carton works only for `push_dir(..., namespace:)` loaders and never updates classes or objects importers (or Rails, via `register`) already hold. See [examples/zeitwerk](../examples/zeitwerk/README.md#reloading).
