# Changelog

## [Unreleased]

### Added

- `Carton.bootstrap_rubygems!` sets up RubyGems inside a Carton's Box so the Carton can activate gems or load Bundler.
- `Carton.with_bundle` takes an optional Gemfile path. Without one, it searches upward from the calling file for `gems.rb` or `Gemfile`.
- `Carton::GemfileNotFound` is raised when `with_bundle` cannot find a Gemfile.
- Public RBS signatures in `sig/carton.rbs`.

### Changed

- `import`, `import_relative`, `export`, and `export_default` are now private Kernel methods, like `require`, so `"str".import(...)` raises `NoMethodError` and objects no longer `respond_to?` them.
- Carton now requires Ruby `>= 4.0.6`, enforced by the gemspec instead of a load-time version check.
- `import 'name'` resolves the feature in the caller's Box and carries only the matching load-path entry into the imported Box, instead of copying the caller's whole `$LOAD_PATH`.
- `Carton.with_bundle` clears a stale `BUNDLE_LOCKFILE` and patches path-gem load paths for the current Box.

### Fixed

- Creating a Carton's Box no longer re-runs the caller's `bundler/setup` through the process-global `BUNDLER_SETUP` variable.
- Imports that bootstrap RubyGems restore the caller's `Gem.loaded_specs` afterwards.
- `export_default` keeps Hash, `nil`, and `false` values as Default Exports instead of treating a Hash as an Export Namespace.
- Bare Carton lookup only finds constants and helpers the Entrypoint defines. Keys are no longer evaluated as Ruby expressions, `key?` no longer calls helpers, and helper errors propagate unchanged.
- Hash-rest patterns (`=> { **rest }`) return every Named Export, or every member of a Bare Carton's Public Surface, instead of an empty hash.

## [0.1.0] - 2026-04-16

Initial release.

[Unreleased]: https://github.com/dtcristo/carton/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dtcristo/carton/releases/tag/v0.1.0
