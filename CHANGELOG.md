# Changelog

## [Unreleased]

### Added

- Added `export_default` for explicit single-value exports.
- Added lookup helpers on named exports and bare imports: `[]`, `fetch`, `fetch_values`, `values_at`, `key?`, `has_key?`, and destructuring through `deconstruct_keys`.
- Replaced the old example set with focused `minimal`, `gems`, and `bundler` tracks, plus focused example READMEs and deeper runtime/design docs.
- Added public RBS signatures, RuboCop, and GitHub Actions CI for the supported development workflow.

### Changed

- `import` now resolves named imports in the caller box and carries only the matching load-path root into the imported box instead of copying the whole caller `$LOAD_PATH`.
- `Carton.with_bundle` now auto-discovers caller `Gemfile`/`gems.rb`, clears stale `BUNDLE_LOCKFILE`, and keeps bundle-managed path gems importable by name under `Ruby::Box`.
- Bundler and RubyGems support now live in separate files, and the bundled example now reflects a small app-style structure plus a support gem.

### Fixed

- Bootstrapped boxed imports now restore the caller's `Gem.loaded_specs` view after RubyGems activation.
- Bundled path gems can now be imported by name, so bundled app code no longer needs to resolve support-gem entry files manually.

## [0.1.0] - 2026-04-16

Initial release.

[Unreleased]: https://github.com/dtcristo/carton/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dtcristo/carton/releases/tag/v0.1.0
