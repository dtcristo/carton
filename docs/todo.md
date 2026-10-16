# TODO

## Upstream

- Fix `RUBY_BOX=1 bundle exec` prelude setup on Ruby 4.0.6 where gemspec evaluation runs before `Gem::Specification` is visible.
- Only reopen boxed `Symbol#to_proc` / `super` upstream work if a current integration reproduces those dispatch failures.

## Library

- Revisit `Carton::Box#gem_path?`; it still relies partly on path heuristics.
- Remove the RubyGems compatibility bootstrap and loaded-spec restoration once boxed path-bundle coverage passes without them.
- Remove the targeted Minitest `object_id` warning suppression once Ruby::Box or Minitest no longer emits it under Ruby 4.0.
- Revisit whether `import` should always return a `Carton::Exports` wrapper with a `default` accessor, or whether the current duck-typed return values are the better long-term fit.
- Decide on Import caching. Every Import builds a fresh Box, so two Cartons importing the same Carton get distinct classes and `is_a?` fails when they exchange its values. Candidate: cache per importing Box with a `fresh: true` escape hatch. Define cache scope, isolation, invalidation, and failure behavior first; avoid a process-global cache.
- Stop `import 'name'` checking `Dir.pwd` before `$LOAD_PATH`. `require` has no cwd step, so results depend on where the app was started. Keep absolute paths and `$LOAD_PATH` only.
- Add `Carton::Error` with `ImportError` and `ExportError` subclasses, and make `GemfileNotFound` a subclass. Replace the plain `RuntimeError`s for exporting outside an Import and exporting twice, and include the paths Carton tried in missing-Import messages.
- Replace the `Carton.bootstrap_rubygems!` plus `Carton.with_bundle { require 'bundler/setup' }` pair with one call such as `Carton.bundle!`, so user code stays the same when the RubyGems workaround goes away.
- Add `keys`, `to_h`, and a readable `inspect` (e.g. `#<Carton::Exports PI, add>`) to `Carton::Exports`.
- Raise a Carton error explaining `RUBY_BOX=1` when boxes are disabled, instead of the raw `Ruby::Box` error from `Carton::Box#initialize`.
- Ship `exe/carton` that sets `RUBY_BOX=1` and execs Ruby, so `carton main.rb` just works.
- Explore an optional Shared Bundle made explicitly available from the Main Box to Cartons. Ruby 4.0.6 optional Boxes copy Master, not Main, so define propagation, isolation, and precedence relative to per-Carton Bundler setup before committing to semantics.

## Examples / docs

- Keep the root README intentionally short and push detail into focused docs.
- Write a guide to using Cartons alongside Rails and Zeitwerk autoloading, after checking what actually works.
- Keep documenting the remaining `RUBY_BOX=1 bundle exec` gemspec failure plainly until the runtime prelude story improves.

## Tooling ideas

- Explore a Prism-based strict mode/linter that enforces `import`/`export` calls at file root and can build a static dependency graph without evaluating code.
- If that exists, add graph validation ideas such as cycle detection, missing import targets, dead imports, and unused exports.
