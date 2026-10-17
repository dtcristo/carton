# Changelog

## [Unreleased]

### Breaking

- Carton now requires Ruby 4.0.7 or later, enforced by the gemspec, and
  Bundler support needs Bundler 4.0.23 or later.
- `export` can be called many times per file, and each call adds to one
  Export Namespace. A capitalized Symbol exports a constant (`export :Money`),
  other Symbols export methods (`export :add`, or `export def add ...`), and
  keywords export plain values. Replace `export add: method(:add)` with
  `export :add`. A missing name raises `NameError`, and a name exported twice
  raises `Carton::ExportError`.
- Exported methods forward when called (`exports.add(...)`), while `[]`,
  `fetch`, and destructuring return the `Method` object. Keyword values are no
  longer invoked: `export handler: -> {}` makes `exports.handler` return the
  lambda.
- `export_default` may be called only once per file and cannot be combined
  with `export`; both raise `Carton::ExportError`. Put other names inside the
  default value.
- Importing a file with no exports (a Bare Carton) returns a `Carton::Exports`
  of the constants and top-level helpers it defines, instead of its
  `Carton::Box`. Importers can no longer `eval`, `require`, or read
  `load_path` inside another Carton. Helpers are callable directly
  (`toolbox.helper`), lookups return their `Method` object
  (`toolbox.fetch(:helper).call`), and constants are read when the import
  finishes. `Carton::Box` is now a private constant.
- Imports are shared across the process. Each Carton file loads once, and
  every later `import` or `import_relative` of it returns the same value, so
  sibling Cartons share classes and Carton state no longer resets per import.
  A Carton that imports itself raises `Carton::ImportError`.
- `import 'name'` no longer checks the current directory before `$LOAD_PATH`,
  so results no longer depend on where the app was started. Use an absolute
  path, `import_relative`, or add the directory to `$LOAD_PATH`.
- `Carton.with_bundle { require 'bundler/setup' }` is replaced by
  `Carton.setup_bundle`. Pass groups as with `Bundler.setup`
  (`Carton.setup_bundle(:default, :test)`) and choose a Gemfile with
  `gemfile:`. Bundler errors raise instead of exiting the process.

### Added

- `Carton::Error`, the base class of every error Carton raises itself, with
  `Carton::ImportError` (circular imports, gem version mismatches) and
  `Carton::ExportError` (repeated or conflicting exports). They replace plain
  `RuntimeError`s and `ArgumentError`s, and are the same classes in every
  Box. `Carton::GemfileNotFound` is now a `Carton::Error`.
- `Carton.setup_bundle(*groups, gemfile: nil)` sets up a Carton's own bundle.
  Without `gemfile:` it searches upward from the calling file for `gems.rb`
  or `Gemfile`. It clears any stale `BUNDLE_LOCKFILE` and restores all of
  `ENV` after setup, so a Carton's bundle variables never reach the rest of
  the process. `Carton::GemfileNotFound` is raised when there is no Gemfile.
- Public RBS signatures in `sig/carton.rbs`.
- `examples/monorepo`: packages as path gems in one Gemfile, imported by gem
  name.
- `examples/rails_in_main`: a Rails API app whose domain logic is a
  Zeitwerk-loaded path-gem Carton.
- `examples/rails_in_cartons`: Rails loaded once in a framework Carton, with
  models and controllers spread across domain Cartons. The Main Box runs only
  Rack.
- `examples/master_prelude`: an optional, unsupported hack that loads Active
  Support's core extensions into Ruby's Master Box so every Carton inherits
  them.

### Changed

- `export` and `export_default` only declare exports from the imported
  Entrypoint. Under plain `require`, or in other files a Carton requires, they
  validate their arguments and do nothing, so Carton-aware files and gems also
  load with `require`.
- Importing a file from an activated gem activates that gem and its runtime
  dependencies in the Carton's Box at the caller's versions. When the caller
  ran Bundler setup, the Box is also restricted to the caller's bundle: every
  locked gem loads at its locked version, and gems outside the lockfile raise
  `LoadError`.
- `import`, `import_relative`, `export`, and `export_default` are private
  Kernel methods, like `require`, so `"str".import(...)` raises
  `NoMethodError` and objects no longer `respond_to?` them.
- `import 'name'` resolves the feature in the caller's Box and carries only
  the matching load-path entry into the imported Box, instead of copying the
  caller's whole `$LOAD_PATH`.
- `RUBY_BOX=1 bundle exec` works, including Gemfiles that evaluate a gemspec.
  Carton no longer patches RubyGems or Bundler.

### Fixed

- Importing without `RUBY_BOX=1` raises `Carton::ImportError` explaining how to
  enable Boxes, instead of `NoMethodError` on `nil`.
- A missing `import_relative` target raises `LoadError` instead of loading a
  same-named feature from the load path (such as the stdlib `json`), and a
  missing absolute `import` raises `LoadError` instead of `Errno::ENOENT`.
- `export_default` keeps Hash, `nil`, and `false` values as Default Exports
  instead of treating a Hash as an Export Namespace.
- A gem Carton imported from another Carton's Box gets its dependencies.
  Activation used to write to the importing Carton's `$LOAD_PATH`, so the
  gem's `require` of a dependency raised `LoadError`.
- A gem Carton's dependencies load at the caller's versions instead of the
  newest installed ones. A later import whose caller has different versions
  activated raises instead of reusing the cached Carton.
- Bare Carton lookup only finds constants and helpers the Entrypoint defines.
  Keys are no longer evaluated as Ruby expressions, and `key?` no longer calls
  helpers.
- Hash-rest patterns (`=> { **rest }`) return every Named Export, or every
  member of a Bare Carton's Public Surface, instead of an empty hash.

## [0.1.0] - 2026-04-16

Initial release.

[Unreleased]: https://github.com/dtcristo/carton/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/dtcristo/carton/releases/tag/v0.1.0
