# TODO

## Bundler / upstream

- Add a Bundler API that can activate a specific Gemfile explicitly instead of relying on process-global `ENV['BUNDLE_GEMFILE']` and `bundler/setup`.
- Make multiple bundle contexts safer for embedded runtimes. Today one carton-local bundle can work, but importing a second conflicting bundle in the same process still resolves against the first bundle's shared RubyGems activation state and can crash under `Ruby::Box`.
- Expose resolved bundle load paths without forcing full `Bundler.setup` and RubyGems entrypoint replacement.
- Make `Bundler.reset!`, `with_original_env`, and `with_unbundled_env` sufficient for re-entering Bundler with another Gemfile, or add a supported replacement for that workflow.
- Improve support for a parent process already running under Bundler importing a child carton that needs a different bundle.
- Make RubyGems activation state such as `Gem.loaded_specs` safely box-local or otherwise explicitly isolateable so two conflicting bundles can coexist under `Ruby::Box` without a subprocess.
- Investigate whether `Bundler.rubygems.replace_entrypoints`, `stub_rubygems`, `Gem::Specification.all`, and `Gem.clear_paths` can be made box-local. Duplicating `Gem.loaded_specs` inside the box isolated a single bundled import from the root box, but it was not enough to make a second conflicting bundle work.

## Ruby::Box / upstream

- Expose more public APIs or clearer guarantees around box-local `$LOAD_PATH`, `$LOADED_FEATURES`, and feature resolution so libraries like Carton do not need to manually copy parent load paths and call `resolve_feature_path`.
- Investigate the crash path after conflicting bundled imports under Ruby 4.0 + `Ruby::Box`, even when the immediate conflict is already surfaced as a Bundler/RubyGems activation error.

## Library

- Revisit `Carton::Box#gem_path?`; it still relies partly on path heuristics.
- Add targeted tests for bundled carton imports instead of covering that behavior only through the complex example.
- Remove the targeted Minitest `object_id` warning suppression once Ruby::Box or Minitest no longer emits it under Ruby 4.0.
- Revisit whether `import` should always return a `Carton::Exports` wrapper with a `default` accessor, or whether the current duck-typed return values are the better long-term fit.

## Examples / docs

- Keep the root README intentionally short and push detail into focused docs.
- Keep documenting current Bundler constraints plainly until the runtime or Bundler story improves.

## Tooling ideas

- Explore a Prism-based strict mode/linter that enforces `import`/`export` calls at file root and can build a static dependency graph without evaluating code.
- If that exists, add graph validation ideas such as cycle detection, missing import targets, dead imports, and unused exports.
