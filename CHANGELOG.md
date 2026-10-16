# Changelog

## [Unreleased]

### Breaking

- `import 'name'` no longer checks the current directory before `$LOAD_PATH`,
  so results no longer depend on where the app was started. Use an absolute
  path, `import_relative`, or add the directory to `$LOAD_PATH`.
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
- `Carton.with_bundle { require 'bundler/setup' }` is replaced by
  `Carton.setup_bundle`. Pass groups like `Bundler.setup`
  (`Carton.setup_bundle(:default, :test)`) and an explicit Gemfile with
  `gemfile:`. Bundler errors now raise instead of exiting the process.

### Added

- `Carton.setup_bundle(*groups, gemfile: nil)` sets up a Carton's own bundle. Without `gemfile:`, it searches upward from the calling file for `gems.rb` or `Gemfile`, clears any stale `BUNDLE_LOCKFILE`, and restores all of `ENV` after setup, so a Carton's bundle variables never reach the rest of the process.
- `Carton::GemfileNotFound` is raised when `setup_bundle` cannot find a Gemfile.
- Public RBS signatures in `sig/carton.rbs`.

### Changed

- `import`, `import_relative`, `export`, and `export_default` are now private Kernel methods, like `require`, so `"str".import(...)` raises `NoMethodError` and objects no longer `respond_to?` them.
- Carton now requires Ruby `>= 4.0.7`, enforced by the gemspec instead of a load-time version check.
- Bundler support needs Bundler 4.0.23 or later. With it, `RUBY_BOX=1 bundle exec` works, including Gemfiles that evaluate a gemspec. Carton no longer patches RubyGems or Bundler.
- `import 'name'` resolves the feature in the caller's Box and carries only the matching load-path entry into the imported Box, instead of copying the caller's whole `$LOAD_PATH`.

### Fixed

- Importing a file from an activated gem now activates that gem and its runtime dependencies in the Carton's Box at the caller's versions. Before, the Box auto-activated the newest installed version of each dependency, ignoring the caller's lockfile. A later import whose caller activates different versions raises instead of reusing the cached Carton.
- `export_default` keeps Hash, `nil`, and `false` values as Default Exports instead of treating a Hash as an Export Namespace.
- Bare Carton lookup only finds constants and helpers the Entrypoint defines. Keys are no longer evaluated as Ruby expressions, and `key?` no longer calls helpers.
- Hash-rest patterns (`=> { **rest }`) return every Named Export, or every member of a Bare Carton's Public Surface, instead of an empty hash.

## [0.1.0] - 2026-04-16

Initial release.

[Unreleased]: https://github.com/dtcristo/carton/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dtcristo/carton/releases/tag/v0.1.0
