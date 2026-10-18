# Changelog

## [Unreleased]

### Added

- `examples/dependency_injection`: a checkout Carton receives order storage, payments, and logging from its host through constructor arguments. File-backed demo adapters stay in Main, and integration tests import the Carton with fakes.

## [0.3.0] - 2026-10-18

`export` now takes one value, which `import` returns as is. This release also adds the `carton-tools` gem, whose `carton` command checks imports and exports and writes RBS, and makes a Carton's autoloads load in its own Box.

### Breaking

- `export` takes one value, which `import` returns as is, and replaces `export_default`: write `export Billing`. Named Exports are removed, since a Ruby module is already a namespace. Export a module of methods instead, or use keywords, which now export a plain Hash: `export version: '1.0'` returns `{ version: '1.0' }`, so read it with `[:version]` or a `=>` pattern. `export` may be called once per Entrypoint, and a Symbol, as in `export def add` or `export :Money`, raises `Carton::ExportError`.
- `Carton::Exports` is renamed `Carton::Namespace`, and only Bare Cartons return it.

### Added

- The `carton-tools` gem, with a `carton` command that reads code with Prism and never runs it, so it needs no `RUBY_BOX=1`. Give it the app's files; it follows imports into every Carton they reach. It is released with `carton` at exactly the same version, and `carton` itself stays the runtime only, with no dependencies and no executable.
- `carton check --strict` fails on warnings as well as errors, and a `# carton:dynamic` comment marks an intentionally dynamic import, such as plugin discovery, to silence its warning.
- `carton check` follows names bound to imports and reports, as errors, a key an exported Hash does not have, read with `fetch(:nope)` or a `=>` pattern, and a reference to an exported module's private constant (`Billing::Tax`).
- `bench/scale.rb` (`rake bench`) measures import time and memory as Cartons and bundles grow; [docs/performance.md](docs/performance.md) has the results.
- `Carton::Namespace#keys` and `#to_h`, and a readable `inspect`: `#<Carton::Namespace add, PI>`.
- `examples/plugins`, a report runner whose two plugins load bigdecimal 3.3.1 and 4.1.1 in one process from their own bundles, while one plugin's `Float#to_s` patch stays out of the host and the other plugin.
- `carton rbs` writes `sig/generated/carton.rbs` so Steep knows what each import returns: an exported constant's own type, a record type for a keyword export, or a generated `Carton::Namespace::*` module for a Bare Carton, typed from rbs-inline `#:` annotations and literal values.
- `carton check` reports missing imports, imports of files inside a Carton, import cycles, `require` calls that load a second copy of an imported Carton, and invalid `export` calls, and exits non-zero on errors.
- `carton check` treats a gem Carton's gemspec as its manifest: it reports each gem the Carton imports or requires that its gemspec does not declare.
- `examples/monorepo/test` shows both ways to test a Carton: a unit test that loads `pricing` with plain `require` and tests its private `Rounding`, and an integration test that imports the packages and sees only their exports. `rake example:<name>` runs an example's `test/**/*_test.rb` after `main.rb`.
- `examples/rails_in_cartons` declares the `logger` dependency its `shop` Carton requires.
- `sig/carton.rbs` declares `Carton::NamespaceMethods`, which `Carton::Namespace` includes.
- The minimal example type-checks with Steep.
- `examples/zeitwerk` shows a Carton whose loader uses Zeitwerk 2.8 nsfiles (`loader.nsfile = 'ns.rb'`): a lazy namespace defined in `ns.rb` loads in the Carton's Box when the app references it first, and reloads with the Carton's other files. Another Carton runs Zeitwerk 2.7.5, without nsfiles, in the same process.
- `examples/zeitwerk` shows Zeitwerk with Cartons outside Rails: a Carton using `Zeitwerk::Loader.for_gem`, a separate Zeitwerk per Box, an app loader that ignores a Carton in its directory, eager loading so autoloads never run in an importer's Box, and reloading, which leaves importers' references stale.

### Changed

- The README and gem summary present Carton as the package system Ruby has been missing, with the tagline "Real boundaries for Ruby", and compare it with Bundler and Packwerk. The README states what a Box does and does not isolate next to its promises, and says where Carton fits today: an app's or monorepo's domains, plugin hosts with conflicting gem versions, Rails inside Cartons as experimental, and not file-by-file loading. Usage recommends exporting a root module, and the docs show shared imports' consequences early, with a plugin testing recipe. Rails in the Main Box is the recommended Rails setup.
- A Bare Carton helper named like a method every `Carton::Namespace` has, such as `def fetch` or `def name`, raises `Carton::ExportError`. It used to replace the built-in method, so `namespace.fetch(:fetch)` broke. `carton check` reports these too.
- A missing `import_relative` target's `LoadError` names the files Carton tried, and a name `import` cannot find says it searched `$LOAD_PATH`, suggesting `import_relative` when a matching file is beside the caller.
- The Rails examples eager load their Cartons' Zeitwerk loaders, so `rails_in_main` no longer loads `Billing::Invoice` in the Main Box, and both gain a Development section on restarting after changes. Each example README now opens with the problem it solves, and `master_prelude` moved out of the README's examples table to an Experiments note.

### Fixed

- An Entrypoint that starts a thread which imports another Carton, and waits for it, no longer blocks forever. The import cache held one global lock while running every Entrypoint; it now locks only its bookkeeping and makes a thread wait only for an Entrypoint another thread is loading.
- `carton check` no longer reports `export` calls in different branches of one `if`, `unless`, or `case` as duplicates, since only one branch runs.
- A shared gem Carton raises `Carton::ImportError` when a later importer locks a different version of a gem it loaded without declaring, such as an undeclared gem the first importer's lockfile allowed, including one it required lazily after its import. Before, only its declared dependencies were compared, so it could be shared silently.
- A Bare Carton imported from a gem no longer exposes `Bundler`, `Psych`, `Date`, or `DateTime`, which Carton's gem activation loaded into its Box.
- A gem Carton's default-gem dependencies, such as `json` and `date`, keep the importer's activated version when a newer one is installed.
- The master_prelude example and Box docs no longer claim the Main Box is unaffected: patches loaded into Master can reach Main and existing Boxes, depending on Ruby's copy-on-write state.
- An autoload a Carton defines, such as a lazy Zeitwerk constant, loads in the Carton's Box even when an importer references it first. It used to run in the importer's Box, often the Main Box, or raise `NameError` when the importer used another name. Autoloaded files also go through the Box's `Kernel#require`, so Zeitwerk's `on_load` callbacks and reloading see them.

## [0.2.0] - 2026-10-17

Cartons are now gem-sized or domain-sized units: a file plus the directory named after it. This release also redesigns exports, shares imports across the process, adds gem and Bundler support, and requires Ruby 4.0.7.

### Breaking

- A Carton is now a file plus the directory named after it, the shape of a gem's `lib/`: `billing.rb` and everything under `billing/`, including Zeitwerk implicit-namespace directories. Importing a file inside a Carton, such as `import 'billing/invoice'`, raises `Carton::ImportError` naming the import to use. It used to load a second copy of the file in its own Box, so its classes did not match the Carton's.
- Carton now requires Ruby 4.0.7 or later, enforced by the gemspec, and Bundler support needs Bundler 4.0.23 or later.
- `export` can be called many times per file, and each call adds to one Export Namespace. A capitalized Symbol exports a constant (`export :Money`), other Symbols export methods (`export :add`, or `export def add ...`), and keywords export plain values. Replace `export add: method(:add)` with `export :add`. A missing name raises `NameError`, and a name exported twice raises `Carton::ExportError`.
- Exported methods forward when called (`exports.add(...)`), while `[]`, `fetch`, and destructuring return the `Method` object. Keyword values are no longer invoked: `export handler: -> {}` makes `exports.handler` return the lambda.
- `export_default` may be called only once per file and cannot be combined with `export`; both raise `Carton::ExportError`. Put other names inside the default value.
- Importing a file with no exports (a Bare Carton) returns a `Carton::Exports` of the constants and top-level helpers it defines, instead of its `Carton::Box`. Importers can no longer `eval`, `require`, or read `load_path` inside another Carton. Helpers are callable directly (`toolbox.helper`), lookups return their `Method` object (`toolbox.fetch(:helper).call`), and constants are read when the import finishes. `Carton::Box` is now a private constant.
- Imports are shared across the process. Each Carton file loads once, and every later `import` or `import_relative` of it returns the same value, so sibling Cartons share classes and Carton state no longer resets per import. A Carton that imports itself raises `Carton::ImportError`.
- `import 'name'` no longer checks the current directory before `$LOAD_PATH`, so results no longer depend on where the app was started. Use an absolute path, `import_relative`, or add the directory to `$LOAD_PATH`.
- `Carton.with_bundle { require 'bundler/setup' }` is replaced by `Carton.setup_bundle`. Pass groups as with `Bundler.setup` (`Carton.setup_bundle(:default, :test)`) and choose a Gemfile with `gemfile:`. Bundler errors raise instead of exiting the process.

### Added

- `import_relative` and absolute `import` accept a gem-shaped directory: `import_relative 'components/billing'` loads `components/billing/lib/billing.rb` with that `lib/` on the Carton's load path.
- `Carton::Error`, the base class of every error Carton raises itself, with `Carton::ImportError` (circular imports, gem version mismatches) and `Carton::ExportError` (repeated or conflicting exports). They replace plain `RuntimeError`s and `ArgumentError`s, and are the same classes in every Box. `Carton::GemfileNotFound` is now a `Carton::Error`.
- `Carton.setup_bundle(*groups, gemfile: nil)` sets up a Carton's own bundle. Without `gemfile:` it searches upward from the calling file for `gems.rb` or `Gemfile`. It clears any stale `BUNDLE_LOCKFILE` and restores all of `ENV` after setup, so a Carton's bundle variables never reach the rest of the process. `Carton::GemfileNotFound` is raised when there is no Gemfile.
- Public RBS signatures in `sig/carton.rbs`.
- `examples/monorepo`: packages as path gems in one Gemfile, imported by gem name.
- `examples/rails_in_main`: a Rails API app whose domain logic is a Zeitwerk-loaded path-gem Carton.
- `examples/rails_in_cartons`: Rails loaded once in a framework Carton, with models and controllers spread across domain Cartons. The Main Box runs only Rack.
- `examples/master_prelude`: an optional, unsupported hack that loads Active Support's core extensions into Ruby's Master Box so every Carton inherits them.

### Changed

- `export` and `export_default` only declare exports from the imported Entrypoint. Under plain `require`, or in other files a Carton requires, they validate their arguments and do nothing, so Carton-aware files and gems also load with `require`.
- Importing a file from an activated gem activates that gem and its runtime dependencies in the Carton's Box at the caller's versions. When the caller ran Bundler setup, the Box is also restricted to the caller's bundle: every locked gem loads at its locked version, and gems outside the lockfile raise `LoadError`.
- `import`, `import_relative`, `export`, and `export_default` are private Kernel methods, like `require`, so `"str".import(...)` raises `NoMethodError` and objects no longer `respond_to?` them.
- `import 'name'` resolves the feature in the caller's Box and carries only the matching load-path entry into the imported Box, instead of copying the caller's whole `$LOAD_PATH`.
- `RUBY_BOX=1 bundle exec` works, including Gemfiles that evaluate a gemspec. Carton no longer patches RubyGems or Bundler.

### Fixed

- Importing without `RUBY_BOX=1` raises `Carton::ImportError` explaining how to enable Boxes, instead of `NoMethodError` on `nil`.
- A missing `import_relative` target raises `LoadError` instead of loading a same-named feature from the load path (such as the stdlib `json`), and a missing absolute `import` raises `LoadError` instead of `Errno::ENOENT`.
- `export_default` keeps Hash, `nil`, and `false` values as Default Exports instead of treating a Hash as an Export Namespace.
- A gem Carton imported from another Carton's Box gets its dependencies. Activation used to write to the importing Carton's `$LOAD_PATH`, so the gem's `require` of a dependency raised `LoadError`.
- A gem Carton's dependencies load at the caller's versions instead of the newest installed ones. A later import whose caller has different versions activated raises instead of reusing the cached Carton.
- Bare Carton lookup only finds constants and helpers the Entrypoint defines. Keys are no longer evaluated as Ruby expressions, and `key?` no longer calls helpers.
- Hash-rest patterns (`=> { **rest }`) return every Named Export, or every member of a Bare Carton's Public Surface, instead of an empty hash.

## [0.1.0] - 2026-04-16

Initial release.

[Unreleased]: https://github.com/dtcristo/carton/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/dtcristo/carton/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/dtcristo/carton/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dtcristo/carton/releases/tag/v0.1.0
