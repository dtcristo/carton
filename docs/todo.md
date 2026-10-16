# TODO

Ordered by priority within each section.

## Library

- Restore all of `ENV` after `Carton.setup_bundle`, not just `BUNDLE_GEMFILE` and `BUNDLE_LOCKFILE`. Bundler setup exports `RUBYOPT=-rbundler/setup`, `RUBYLIB`, `BUNDLER_SETUP`, `GEM_HOME`, `PATH`, and `BUNDLER_ORIG_*`, so subprocesses started by Main after importing a bundled Carton load the wrong bundle. Decide whether subprocesses started from inside the Carton should keep its bundle.
- Raise a Carton error explaining `RUBY_BOX=1` when boxes are disabled, instead of the raw `Ruby::Box` error from `Carton::Box#initialize`.
- Add `Carton::Error` with `ImportError` and `ExportError` subclasses, and make `GemfileNotFound` a subclass. Replace the plain `RuntimeError`s for exporting outside an Import and exporting twice, and include the paths Carton tried in missing-Import messages.
- Stop `import 'name'` checking `Dir.pwd` before `$LOAD_PATH`. `require` has no cwd step, so results depend on where the app was started. Keep absolute paths and `$LOAD_PATH` only.
- Add `keys`, `to_h`, and a readable `inspect` (e.g. `#<Carton::Exports PI, add>`) to `Carton::Exports`.
- Ship `exe/carton` that sets `RUBY_BOX=1` and execs Ruby, so `carton main.rb` just works.
- Consider a fresh-Import escape hatch (e.g. `import(path, fresh: true)`) if tests or tools need an isolated copy of a shared Carton.
- Revisit whether `import` should always return a `Carton::Exports` wrapper with a `default` accessor, or whether the current duck-typed return values are the better long-term fit.
- Explore an optional Shared Bundle made explicitly available from the Main Box to Cartons. Optional Boxes copy Master, not Main, so define propagation, isolation, and precedence relative to per-Carton Bundler setup before committing to semantics.

## Upstream

See [upstream.md](internals/upstream.md) for detail.

- Send a one-line fix for `doc/language/box.md`, which still says Main is created at the end of bootstrap.
- If restoring `ENV` in Carton is not enough, propose a Bundler way to set up a bundle in-process without exporting subprocess `ENV`, or to pass the Gemfile without `BUNDLE_GEMFILE`.

## Docs

- Write a guide to using Cartons alongside Rails and Zeitwerk autoloading, after checking what actually works.

## Tooling ideas

- Explore a Prism-based strict mode/linter that enforces `import`/`export` calls at file root and can build a static dependency graph without evaluating code.
- If that exists, add graph validation ideas such as cycle detection, missing import targets, dead imports, and unused exports.
