# TODO

Ordered by priority within each section.

## Library

- Raise a Carton error explaining `RUBY_BOX=1` when boxes are disabled, instead of the raw `Ruby::Box` error from `Carton::Box#initialize`.
- Add `Carton::Error` with `ImportError` and `ExportError` subclasses, and make `GemfileNotFound` a subclass. Replace the plain `RuntimeError`s for exporting twice, circular imports, and gem version mismatches, and include the paths Carton tried in missing-Import messages.
- Add `keys`, `to_h`, and a readable `inspect` (e.g. `#<Carton::Exports PI, add>`) to `Carton::Exports`.
- Ship `exe/carton` that sets `RUBY_BOX=1` and execs Ruby, so `carton main.rb` just works.
- Consider a fresh-Import escape hatch (e.g. `import(path, fresh: true)`) if tests or tools need an isolated copy of a shared Carton.
- Revisit whether `import` should always return a `Carton::Exports` wrapper with a `default` accessor, or whether the current duck-typed return values are the better long-term fit.
- Decide whether gem Cartons should key Imports by gem instead of Entrypoint path, so `import 'gem'` and `import 'gem/sub'` share one Box.
- Cache rebuilt specs per caller bundle: strict gem Cartons rebuild every locked spec from YAML on each first import, which grows with bundle size.
- Propose the Bundler activation API from [upstream.md](internals/upstream.md) and comment on Ruby #22275 with Carton's use case.
- Decide what non-gem Cartons (plain `import_relative` directories) should see from the caller's bundle; today they see nothing unless they call `setup_bundle`.

## Upstream

See [upstream.md](internals/upstream.md) for detail.

- Ask Ruby to support template Boxes: either bless preparing `Ruby::Box.master` before Boxes exist, or add an API such as `Ruby::Box.new(template: box)`. Evidence: `examples/master_prelude` and the per-Box cost of shared monkey patches.
- Idea, low odds: constant binding in patterns (`import(path) => { Name: }`). Matz limits pattern targets to locals (#18408); see [constant-binding-patterns.md](internals/constant-binding-patterns.md). `export_default` and plain assignment already cover it.
- Send a one-line fix for `doc/language/box.md`, which still says Main is created at the end of bootstrap.

## Docs

- Consider a small Carton helper for the `register` pattern in `examples/rails_in_cartons` if more framework integrations need it.
- Expand the Rails example into a guide: passing records into Cartons, testing Cartons in a Rails app, and reloading (Cartons are process-lifetime today).

## Tooling ideas

- Explore a Prism-based strict mode/linter that enforces `import`/`export` calls at file root and can build a static dependency graph without evaluating code.
- If that exists, add graph validation ideas such as cycle detection, missing import targets, dead imports, and unused exports.
