# TODO

## Upstream

- Fix `RUBY_BOX=1 bundle exec` prelude setup on Ruby 4.0.6 where gemspec evaluation runs before `Gem::Specification` is visible.
- Only reopen boxed `Symbol#to_proc` / `super` upstream work if a current integration reproduces those dispatch failures.

## Library

- Revisit `Carton::Box#gem_path?`; it still relies partly on path heuristics.
- Remove the RubyGems compatibility bootstrap and loaded-spec restoration once boxed path-bundle coverage passes without them.
- Remove the targeted Minitest `object_id` warning suppression once Ruby::Box or Minitest no longer emits it under Ruby 4.0.
- Revisit whether `import` should always return a `Carton::Exports` wrapper with a `default` accessor, or whether the current duck-typed return values are the better long-term fit.
- Revisit Import caching if stable identity and shared dependencies justify it. Define cache scope, isolation, invalidation, failure behavior, and a fresh-Import escape hatch before changing the current uncached behavior; avoid a process-global cache.
- Explore an optional Shared Bundle made explicitly available from the Main Box to Cartons. Ruby 4.0.6 optional Boxes copy Master, not Main, so define propagation, isolation, and precedence relative to per-Carton Bundler setup before committing to semantics.

## Examples / docs

- Keep the root README intentionally short and push detail into focused docs.
- Keep documenting the remaining `RUBY_BOX=1 bundle exec` gemspec failure plainly until the runtime prelude story improves.

## Tooling ideas

- Explore a Prism-based strict mode/linter that enforces `import`/`export` calls at file root and can build a static dependency graph without evaluating code.
- If that exists, add graph validation ideas such as cycle detection, missing import targets, dead imports, and unused exports.
