# TODO

## Upstream

- Fix boxed `Symbol#to_proc` and `super` dispatch, then rerun the upstream path-bundle integration spec.
- Fix `RUBY_BOX=1 bundle exec` prelude setup, where gemspec evaluation can run before `Gem::Specification` is visible.
- Upstream only residual RubyGems/Bundler changes proven necessary after the Ruby fixes.

## Library

- Revisit `Carton::Box#gem_path?`; it still relies partly on path heuristics.
- Remove the RubyGems compatibility bootstrap and loaded-spec restoration once boxed path-bundle coverage passes without them.
- Remove the targeted Minitest `object_id` warning suppression once Ruby::Box or Minitest no longer emits it under Ruby 4.0.
- Revisit whether `import` should always return a `Carton::Exports` wrapper with a `default` accessor, or whether the current duck-typed return values are the better long-term fit.

## Examples / docs

- Keep the root README intentionally short and push detail into focused docs.
- Keep documenting current Bundler constraints plainly until the runtime or Bundler story improves.

## Tooling ideas

- Explore a Prism-based strict mode/linter that enforces `import`/`export` calls at file root and can build a static dependency graph without evaluating code.
- If that exists, add graph validation ideas such as cycle detection, missing import targets, dead imports, and unused exports.
