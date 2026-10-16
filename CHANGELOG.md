# Changelog

## [Unreleased]

### Breaking

- `export` now exports methods by name: `export :add, PI: 3.14159`.
  `exports.add(...)` forwards to the method, while `[]`, `fetch`, and
  destructuring return the `Method` object. A missing method raises
  `NameError`, and a name given both positionally and as a keyword raises
  `ArgumentError`. Replace `export add: method(:add)` with `export :add`.
- Keyword export values are no longer invoked. `export handler: -> {}` now
  makes `exports.handler` return the lambda instead of calling it.
- Bare Carton lookups (`[]`, `fetch`, destructuring) now return the helper's
  `Method` object instead of calling it. Use `box.fetch(:helper).call`.
- Imports are now shared across the process. Each Carton file loads once,
  and every later `import` or `import_relative` of that file returns the same
  value, so sibling Cartons share classes. Carton state no longer resets per
  import. A Carton that imports itself raises `circular import`.

### Added

- `Carton.with_bundle` takes an optional Gemfile path. Without one, it searches upward from the calling file for `gems.rb` or `Gemfile`.
- `Carton::GemfileNotFound` is raised when `with_bundle` cannot find a Gemfile.
- Public RBS signatures in `sig/carton.rbs`.

### Changed

- `import`, `import_relative`, `export`, and `export_default` are now private Kernel methods, like `require`, so `"str".import(...)` raises `NoMethodError` and objects no longer `respond_to?` them.
- Carton now requires Ruby `>= 4.0.7`, enforced by the gemspec instead of a load-time version check.
- `import 'name'` resolves the feature in the caller's Box and carries only the matching load-path entry into the imported Box, instead of copying the caller's whole `$LOAD_PATH`.
- `Carton.with_bundle` clears a stale `BUNDLE_LOCKFILE`.

### Fixed

- `export_default` keeps Hash, `nil`, and `false` values as Default Exports instead of treating a Hash as an Export Namespace.
- Bare Carton lookup only finds constants and helpers the Entrypoint defines. Keys are no longer evaluated as Ruby expressions, and `key?` no longer calls helpers.
- Hash-rest patterns (`=> { **rest }`) return every Named Export, or every member of a Bare Carton's Public Surface, instead of an empty hash.

## [0.1.0] - 2026-04-16

Initial release.

[Unreleased]: https://github.com/dtcristo/carton/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dtcristo/carton/releases/tag/v0.1.0
