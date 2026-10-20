# TODO

Ordered by priority within each section.

## Library

- Evaluate the [Shared Gems spike](../spikes/shared_gems/results.md) before choosing a runtime API. Selected Active Support checks and two Active Record domain Cartons work; local shared-feature requires, existing Gem Carton activation, and the unmodified Rails example fail. Define an explicit dependency/require contract and builtin-state compatibility policy before integrating it.

- Follow up the [Rails reloading spike](../spikes/rails_reloading/README.md): choose a retained-host callback contract, track and invalidate Imports without private runtime inspection, define concurrency and failed-reload behavior, and measure memory over repeated reloads. The spike verifies two serial reloads while retaining Rails and its database, first after editing a model and controller, then after editing only the model; ordinary apps still restart on change. Extend the Rails example's explicit CLI bridge to a verified interactive `rails console` and measure what Active Support's core extensions cost each domain Box.
- Consider an opt-in guard that warns when a Carton reopens a class another Carton exported. A `TracePoint(:class)` in the Main Box sees `class Foo` reopens in every Box, and Carton knows which Carton exported each class; it would not catch `class_eval` or `define_method`.
- Deferred until nsfiles are more common in Ruby: `Carton.nsfile = 'ns.rb'`, off by default and working like Zeitwerk's `nsfile`, so a directory's `shipping/ns.rb` can be its Entrypoint and `import_relative 'shipping'` finds it. A Carton setting, not Zeitwerk's config, since the Carton's loader is set up by the Entrypoint being resolved; `carton check` would need the same setting. Today the Entrypoint must sit beside its directory ([examples/zeitwerk](../examples/zeitwerk/README.md#namespaces-in-nsfiles)).
- If large Cartons need lazy parts, let a Carton declare public sub-entrypoints in its Interior that can be imported, like the `exports` field in Node's `package.json`. Today no Interior file can be imported.
- Stop loading Psych into each Gem Carton's Box: rebuilding specs from YAML costs about 86 ms of a Gem Carton's 195 ms ([performance.md](performance.md)). Avoid a `Marshal` round trip, which RubyGems had to special-case across Boxes. If Boxes can start from a resolved load path ([Ruby #22275](https://bugs.ruby-lang.org/issues/22275)), spec rebuilding goes away entirely.
- Drop the autoload `require` workaround in `Carton::Box` once the minimum Ruby includes [ruby/ruby#18534](https://github.com/ruby/ruby/pull/18534) ([Bug #21830](https://bugs.ruby-lang.org/issues/21830)).
- Parked: strict Gem Cartons, which load only a Gem Carton's declared dependencies at runtime. Wait for [Ruby #22275](https://bugs.ruby-lang.org/issues/22275) to settle whether Boxes get resolved load paths, which would make this a load-path choice instead of more Bundler internals. `carton check` already reports undeclared gems.
- Decide what non-Gem Cartons (plain `import_relative` directories) should see from the importer's bundle; today they see nothing unless they call `setup_bundle`.
- Consider an escape hatch from Shared Imports (e.g. `import(path, fresh: true)`) if tests or tools need an isolated copy of a shared Carton.
- Consider a small helper for the `register` pattern in `examples/rails_in_cartons` if more framework integrations need it.
- Test that the gem builds, installs into a clean gem home, and can be required and imported.

## Tooling

`carton rbs`, `carton check`, and the Gem Carton monorepo example have shipped. The remaining tooling work from [dtcristo/carton#38](https://github.com/dtcristo/carton/issues/38) and [dtcristo/carton#32](https://github.com/dtcristo/carton/issues/32) is listed below; strict Gem Cartons remain parked under Library.

- `carton check`: report unused exports and dead imports.
- `carton check`: resolve imports inside a Carton that calls `setup_bundle` against its own `Gemfile.lock`, then report a Gem Carton shared by importers whose lockfiles lock its dependencies at different versions (a runtime `Carton::ImportError` today).
- `carton rbs`: read exported top-level method types from a Carton's own RBS, not only rbs-inline `#:` annotations.
- `carton rbs`: optionally write Steepfile targets, one per Carton, so Cartons' internal constants cannot clash in RBS's single namespace.
- Sorbet through a Tapioca DSL compiler, if `tapioca dsl` works under `RUBY_BOX=1`.

## Upstream

- Report the [Ruby 4.0.7 visibility leak](../spikes/shared_gems/09_visibility_leak.rb) separately from template Boxes: changing an existing builtin method's visibility in an Optional Box mutates the shared method entry, reaching Main and Master. See the [source diagnosis](../spikes/shared_gems/results.md#ruby-source-and-the-missing-vm-support).

See [upstream.md](internals/upstream.md) for detail.

- Measure and report `Ruby::Box.new` cost (about 55 ms and 2.2 MB per Box on 4.0.7, see [performance.md](performance.md)), the floor for every import.
- Comment on [Ruby #22275](https://bugs.ruby-lang.org/issues/22275) with Carton's use case, supporting Boxes created from a resolved load path (proposed there on 2026-09-25), and reframe [dtcristo/carton#16](https://github.com/dtcristo/carton/issues/16) around it.
- Post the template Box proposal ([dtcristo/carton#25](https://github.com/dtcristo/carton/issues/25)) to bugs.ruby-lang.org: official template Box support, framed as requirements derived from how Box copy-on-write works, leaving Master clean.
- Send small fixes for Ruby's Box docs: `doc/language/box.md` still says Main is created at the end of bootstrap and has an unfinished sentence about the Root Box, and the `Ruby::Box` class docs omit `master`, `root`, and `main` ([box-names.md](internals/box-names.md#stale-upstream-docs)).
- Idea, low odds: constant binding in patterns (`import(path) => { Name: }`). Matz limits pattern targets to locals ([#18408](https://bugs.ruby-lang.org/issues/18408)); see [constant-binding-patterns.md](internals/constant-binding-patterns.md). `export` and plain assignment already cover it.

## Docs

- Extend the website's Rails guide: passing records into Cartons and testing Cartons in a Rails app. For reloading, the Rails examples document restarting on change; Zeitwerk reloading inside a Carton works only for `push_dir(..., namespace:)` loaders and never updates classes or objects importers (or Rails, via `register`) already hold. See [examples/zeitwerk](../examples/zeitwerk/README.md#reloading).
