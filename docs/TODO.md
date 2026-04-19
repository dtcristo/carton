# TODO

## Upstream

- Keep RubyGems/Bundler upstream work limited to the necessary-only plan in [RUBYGEMS_UPSTREAM.md](RUBYGEMS_UPSTREAM.md). Prototype the boxed RubyGems patch in Carton first, then upstream only the smallest supportable surface.
- Keep Ruby upstream work limited to the required `Ruby::Box` runtime fix in [RUBY_UPSTREAM.md](RUBY_UPSTREAM.md). Avoid broader box/gem redesign unless the RubyGems prototype proves it is necessary.

## Library

- Revisit `Carton::Box#gem_path?`; it still relies partly on path heuristics.
- Keep the supported main-box Bundler story simple: ordinary app setup can use `Carton.with_bundle { require 'bundler/setup' }`, while bundled cartons inside fresh boxes still use explicit `Carton.bootstrap_rubygems!`.
- Remove the targeted Minitest `object_id` warning suppression once Ruby::Box or Minitest no longer emits it under Ruby 4.0.
- Revisit whether `import` should always return a `Carton::Exports` wrapper with a `default` accessor, or whether the current duck-typed return values are the better long-term fit.

## Examples / docs

- Keep the root README intentionally short and push detail into focused docs.
- Keep documenting current Bundler constraints plainly until the runtime or Bundler story improves.

## Tooling ideas

- Explore a Prism-based strict mode/linter that enforces `import`/`export` calls at file root and can build a static dependency graph without evaluating code.
- If that exists, add graph validation ideas such as cycle detection, missing import targets, dead imports, and unused exports.
