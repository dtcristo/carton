# TODO

## Bundler / upstream

- Add a Bundler API that can activate a specific Gemfile explicitly instead of relying on process-global `ENV['BUNDLE_GEMFILE']` and `bundler/setup`.
- Make multiple bundle contexts safer for embedded runtimes. Today one package-local bundle can work, but importing a second conflicting bundle in the same process still resolves against the first bundle and can crash under `Ruby::Box`.
- Expose resolved bundle load paths without forcing full `Bundler.setup` and RubyGems entrypoint replacement.
- Make `Bundler.reset!`, `with_original_env`, and `with_unbundled_env` sufficient for re-entering Bundler with another Gemfile, or add a supported replacement for that workflow.
- Improve support for a parent process already running under Bundler importing a child package that needs a different bundle.

## Library

- Revisit `Package::Box#gem_path?`; it still relies partly on path heuristics.
- Consider a tiny public helper for bundle-wrapped imports if the example helper pattern proves stable in real usage.
- Add targeted tests for bundled package imports instead of covering that behavior only through the complex example.
- Investigate the Minitest `object_id` warning that appears under Ruby 4.0 + `Ruby::Box`.
- Review whether `Package::Box` and `Package::Exports` lookup helpers can be simplified further without obscuring the behavior.

## Examples / docs

- Keep the root README intentionally short and push detail into focused docs.
- Keep documenting current Bundler constraints plainly until the runtime or Bundler story improves.
