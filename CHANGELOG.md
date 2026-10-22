# Changelog

## [Unreleased]

### Added

- `carton graph PATH...` prints the import graph as Mermaid (default) or DOT, with lazy imports dashed and the app as `Main` (#111).
- `carton why FROM TO` prints the shortest chain of imports from a file to a Carton (#111).
- `carton rbs --check` exits 1 when the RBS file is missing or stale and writes nothing; `carton rbs` no longer rewrites an unchanged file (#111).
- `--exclude GLOB` skips files in directory scans, which now always skip `vendor/bundle`. A directory with no Ruby files is a usage error (#111).
- `carton --version`, `carton -v`, and `carton help [COMMAND]`, plus `-h`/`--help` and `-v`/`--version` on every command (#111).
- `carton check` reports `export` with no value or several (#111).
- Add `examples/rack`, where a plain `config.ru` mounts domain Cartons that each export a Rack app, with no web framework (#PR).

### Changed

- `carton check` gives each problem a stable rule ID and a column. Text output is `file:line:column: level: message [rule]` with pluralised counts, and JSON adds `version: 1`, `rule`, and `column` (#111).
- `carton check` names Cartons by their Entrypoint path relative to the working directory, such as `billing.rb`, instead of the basename (#111).
- Use Faraday instead of bigdecimal as the third-party gem in the Plugins and Monorepo examples and the docs. Plugins loads Faraday 1.10 and 2.15 side by side, one through a Transitive Carton with its own Carton Bundle (#PR).
- Move the Zeitwerk example's checks from `main.rb` into `test/zeitwerk_test.rb`, leaving a short demo (#PR).
- Align the Rails and Hanami examples: one `Framework.register` signature, one import-wrapper naming scheme, no `Carton.setup_bundle` in Hanami's Gem Cartons, and shorter `main.rb` demos (#PR).
- Label Carton, bundle, and export boundaries the same way in every example (#PR).
- Set both gems' homepages to the Carton website and retain their GitHub source links (#108).
- Simplify the example gemspecs to required metadata, packaged files, and dependencies (#108).
- Rename the Rails and Hanami examples' Carton directories from `components/` to `cartons/` (#108).
- Keep the Minimal example focused on runtime boundaries and move static-check and RBS/Steep demonstrations into the Tooling example (#108).

### Fixed

- `require 'carton'` works without RubyGems, as under `ruby --disable-gems`, and defines `Carton::VERSION` (#110).
- `import_relative` resolves against the calling file's absolute path, so it still works after `Dir.chdir` in a script run by relative path. From `eval` it raises `LoadError`, as `require_relative` does (#110).
- Importing a name that resolves to a native extension, such as `import 'etc'`, raises `Carton::ImportError` saying only a `.rb` Entrypoint can be imported, instead of an `ExportError` with an empty path (#110).
- Concurrent `Carton.setup_bundle` calls on different threads, from any Carton, take turns, so Bundler never reads another Carton's `BUNDLE_GEMFILE` (#110).
- Concurrent Shared Imports of a Carton that uses locked gems no longer race while checking gem versions (#110).
- `export` in an Entrypoint method called after its Import finishes is inert, instead of raising or setting an unread value (#110).
- A Shared Import's version conflict with a locked gem now says the import "locks" that version, not "activates" it (#110).
- The RBS signatures accept a `Pathname` for `import` and `import_relative`, and String groups for `setup_bundle` (#110).
- `carton check` finds import cycles in linear time; it took exponential time even without cycles. It reports one shortest cycle per set of Cartons that import each other (#111).
- Paths sharing the working directory's prefix, such as `../app-x` from `app/`, are no longer mangled in messages (#111).
- `--help` on a command no longer calls `exit` or writes to `$stdout` directly, and `--version` on a command works (#111).
- Unreadable files and an `rbs -o` directory exit 2 with `carton: PATH: reason` instead of a backtrace (#111).
- `self.export` gets the same duplicate, Symbol, and arity checks and RBS typing as `export` (#111).
- Discovery resolves each import once instead of on every pass (#111).

### Removed

- Remove the manual RubyGems example; the Plugins example still demonstrates conflicting gem versions (#108, #PR).
- Remove the Bundler example, which duplicated the Plugins and Monorepo examples; Plugins now covers its Transitive Carton with its own Carton Bundle (#PR).

## [0.4.0] - 2026-10-22

Every imported Entrypoint now requires an explicit Export; Bare Cartons and `Carton::Namespace` are removed. `carton check` adds unused import and shared-object reopening warnings plus JSON reports. The Rails and Hanami examples share a Customers and Billing workflow, and Bundler support starts at 4.0.20 (#71, #79, #82, #83, #93, #100, #107).

### Breaking

- Every imported Entrypoint must call `export` exactly once; an import with no Export raises `Carton::ExportError` after loading. Removed Bare Cartons and `Carton::Namespace`; adapt legacy files and gems with a distinct Entrypoint that requires them and explicitly exports the chosen value. Imports still return that value exactly, including `nil` and `false`, and plain `require` keeps working (#107).

### Added

- `examples/hanami_in_cartons` implements the Rails examples' Customers/Billing workflow with Hanami slices, Dry contracts, types and operations, ROM SQLite repos, HTML/JSON responses, and a CLI bridge. Tests cover lazy/eager loading, Box ownership, persistence across processes, and Puma HTTP (#93).
- `carton check` warns about unused import bindings and class/module definitions that open imported shared objects, and `--format json` reports problems and counts for CI and editors. This recovers the applicable parts of the stranded static-checks work; its unused Named Export check is obsolete under the single-value Export model (#54, #82).
- An experimental Rails-in-Cartons reloading spike rebuilds changed domain Cartons and their Importers in a scratch copy, explicitly refreshes a retained Rails host's domain references and registered classes, and verifies requests after two reloads without losing records. It adds no runtime reload interface (#67).
- `examples/exports` demonstrates Hash and callable exports, an explicit adapter for legacy Ruby, and Ruby pattern matching without gems or Bundler. The plugin testing recipe is now a runnable test with its own bundle (#64, #107).
- `examples/dependency_injection`: a checkout Carton receives order storage, payments, and logging from its host through constructor arguments. File-backed demo adapters stay in Main, and integration tests import the Carton with fakes (#63).

### Changed

- The Hanami example's Framework, Customers, Billing, and Shop are gem-shaped components under `components/`, matching the Rails example, and import each other with `import 'name'` instead of `import_relative`. Both example guides show the framework and customers Entrypoints above billing and shop (#103).
- Renamed the Rails and Hanami example directories to `examples/rails` and `examples/hanami`, with matching Rake tasks and updated fixture paths. Their existing docs URLs still work (#100).

- Aligned the homepage, share previews, README, docs, and gem descriptions around explicit imports and exports, separate dependencies, and runtime boundaries. The homepage introduction is centred and its page title no longer repeats the project name (#98).
- The website has three sections, Start here, Guides, and Reference, and the sidebar shows only the current one. Each example's guide moved from its README to a website page that shows its code from the repository. The reference is now API docs in YARD's shape, tested against `sig/carton.rbs`, with a page per `carton` command tested against its usage (#90).
- Renamed the Rails-in-Main example to `rails_with_carton_domain` and aligned both Rails examples around Customers and Billing: domain-owned registration, validation, exact invoice pricing, and persistence through injected repositories. The conventional app keeps Rails adapters in Main; the Engine app owns them in its domain Cartons. Removed the unrelated jobs, updated the private reload fixture, and placed both examples together in the docs (#83).

- Expanded Rails-in-Main into a conventional Rails app with migrations, HTML/JSON responses, an Active Job, standard CLI commands, and isolated Billing integration tests (#80, #81).

- The Rails-in-Cartons example uses isolated Rails Engines with domain-owned loaders, migrations, HTML views, GlobalID jobs, and an explicit Rails CLI bridge (#79).

- The website is now the only user guide and reference: `docs/usage.md` is gone, its remaining details moved to the website, which adds Examples and Rails pages, and the website's Status page is the only place that tracks readiness (#77).
- Moved the unsupported Master prelude and private Rails reloading experiments into `spikes/`, with dedicated tasks and CI coverage; both Rails examples remain in `examples/`. The reloading spike reuses the Rails-in-Cartons app as a read-only fixture (#76).

- Bundler support now starts at 4.0.20, the first release with the gemspec evaluation fix Carton needs inside Boxes. CI and the example bundles use that minimum (#71).
- `examples/monorepo` keeps its Cartons under `cartons/` instead of `packages/` (#65).
- `CONTEXT.md` groups the glossary and adds Interior, Gem-shaped Directory, Root Box, User Box, Carton Box, Template Box, Importer, First Importer, Second Copy, Dynamic Import, Helper, Gem Closure, Carton Bundle, and Undeclared Gem. The docs, comments, and `carton-tools` internals use these terms (#65).
- `docs/internals/root-box-vs-main-box.md` is now `docs/internals/box-names.md`, which records upstream Ruby's Box names and how they were chosen (#65).
- The examples guide explains each example's purpose and setup. The minimal app now contains only working Imports, with intentional violations in a separate file for static checks. The guides and comments follow `CONTEXT.md`, including Interior, Public Surface, Importer, Carton Bundle, and Helper. The Rails guides share restart guidance, and Bundler and Zeitwerk examples use clearer labels and names (#64).

### Removed

- Removed `examples/rails_with_carton_domain` and its guide, leaving one Rails example with domain-owned Engines (#100).

### Fixed

- Sample path gems declare and require Carton instead of relying on the host to preload it; the monorepo's leaf gems also work with ordinary `require` without Boxes enabled. The Rails shop gem includes its database configuration. Example docs distinguish bundle installation from activation and correct the undeclared-import demonstration and Rails class-sharing explanation (#64).

## [0.3.0] - 2026-10-18

`export` now takes one value, which `import` returns as is. This release also adds the `carton-tools` gem, whose `carton` command checks imports and exports and writes RBS, and makes a Carton's autoloads load in its own Box (#41, #48, #58, #59).

### Breaking

- `export` takes one value, which `import` returns as is, and replaces `export_default`: write `export Billing`. Named Exports are removed, since a Ruby module is already a namespace. Export a module of methods instead, or use keywords, which now export a plain Hash: `export version: '1.0'` returns `{ version: '1.0' }`, so read it with `[:version]` or a `=>` pattern. `export` may be called once per Entrypoint, and a Symbol, as in `export def add` or `export :Money`, raises `Carton::ExportError` (#59).
- `Carton::Exports` is renamed `Carton::Namespace`, and only Bare Cartons return it (#59).

### Added

- The `carton-tools` gem, with a `carton` command that reads code with Prism and never runs it, so it needs no `RUBY_BOX=1`. Give it the app's files; it follows imports into every Carton they reach. It is released with `carton` at exactly the same version, and `carton` itself stays the runtime only, with no dependencies and no executable (#41, #58).
- `carton check --strict` fails on warnings as well as errors, and a `# carton:dynamic` comment marks an intentionally dynamic import, such as plugin discovery, to silence its warning (#53).
- `carton check` follows names bound to imports and reports, as errors, a key an exported Hash does not have, read with `fetch(:nope)` or a `=>` pattern, and a reference to an exported module's private constant (`Billing::Tax`) (#53, #59).
- `bench/scale.rb` (`rake bench`) measures import time and memory as Cartons and bundles grow; [docs/performance.md](docs/performance.md) has the results (#50).
- `Carton::Namespace#keys` and `#to_h`, and a readable `inspect`: `#<Carton::Namespace add, PI>` (#43, #59).
- `examples/plugins`, a report runner whose two plugins load bigdecimal 3.3.1 and 4.1.1 in one process from their own bundles, while one plugin's `Float#to_s` patch stays out of the host and the other plugin (#45).
- `carton rbs` writes `sig/generated/carton.rbs` so Steep knows what each import returns: an exported constant's own type, a record type for a keyword export, or a generated `Carton::Namespace::*` module for a Bare Carton, typed from rbs-inline `#:` annotations and literal values (#41, #59).
- `carton check` reports missing imports, imports of files inside a Carton, import cycles, `require` calls that load a second copy of an imported Carton, and invalid `export` calls, and exits non-zero on errors (#41, #59).
- `carton check` treats a gem Carton's gemspec as its manifest: it reports each gem the Carton imports or requires that its gemspec does not declare (#42).
- `examples/monorepo/test` shows both ways to test a Carton: a unit test that loads `pricing` with plain `require` and tests its private `Rounding`, and an integration test that imports the packages and sees only their exports. `rake example:<name>` runs an example's `test/**/*_test.rb` after `main.rb` (#44).
- `examples/rails_in_cartons` declares the `logger` dependency its `shop` Carton requires (#42).
- `sig/carton.rbs` declares `Carton::NamespaceMethods`, which `Carton::Namespace` includes (#41, #59).
- The minimal example type-checks with Steep (#41).
- `examples/zeitwerk` shows a Carton whose loader uses Zeitwerk 2.8 nsfiles (`loader.nsfile = 'ns.rb'`): a lazy namespace defined in `ns.rb` loads in the Carton's Box when the app references it first, and reloads with the Carton's other files. Another Carton runs Zeitwerk 2.7.5, without nsfiles, in the same process (#60).
- `examples/zeitwerk` shows Zeitwerk with Cartons outside Rails: a Carton using `Zeitwerk::Loader.for_gem`, a separate Zeitwerk per Box, an app loader that ignores a Carton in its directory, eager loading so autoloads never run in an importer's Box, and reloading, which leaves importers' references stale (#46).

### Changed

- The README and gem summary present Carton as the package system Ruby has been missing, with the tagline "Real boundaries for Ruby", and compare it with Bundler and Packwerk. The README states what a Box does and does not isolate next to its promises, and says where Carton fits today: an app's or monorepo's domains, plugin hosts with conflicting gem versions, Rails inside Cartons as experimental, and not file-by-file loading. Usage recommends exporting a root module, and the docs show shared imports' consequences early, with a plugin testing recipe. Rails in the Main Box is the recommended Rails setup (#56, #57, #59).
- A Bare Carton helper named like a method every `Carton::Namespace` has, such as `def fetch` or `def name`, raises `Carton::ExportError`. It used to replace the built-in method, so `namespace.fetch(:fetch)` broke. `carton check` reports these too (#43).
- A missing `import_relative` target's `LoadError` names the files Carton tried, and a name `import` cannot find says it searched `$LOAD_PATH`, suggesting `import_relative` when a matching file is beside the caller (#43).
- The Rails examples eager load their Cartons' Zeitwerk loaders, so `rails_in_main` no longer loads `Billing::Invoice` in the Main Box, and both gain a Development section on restarting after changes. Each example README now opens with the problem it solves, and `master_prelude` moved out of the README's examples table to an Experiments note (#47).

### Fixed

- An Entrypoint that starts a thread which imports another Carton, and waits for it, no longer blocks forever. The import cache held one global lock while running every Entrypoint; it now locks only its bookkeeping and makes a thread wait only for an Entrypoint another thread is loading (#55).
- `carton check` no longer reports `export` calls in different branches of one `if`, `unless`, or `case` as duplicates, since only one branch runs (#53).
- A shared gem Carton raises `Carton::ImportError` when a later importer locks a different version of a gem it loaded without declaring, such as an undeclared gem the first importer's lockfile allowed, including one it required lazily after its import. Before, only its declared dependencies were compared, so it could be shared silently (#52).
- A Bare Carton imported from a gem no longer exposes `Bundler`, `Psych`, `Date`, or `DateTime`, which Carton's gem activation loaded into its Box (#52).
- A gem Carton's default-gem dependencies, such as `json` and `date`, keep the importer's activated version when a newer one is installed (#52).
- The master_prelude example and Box docs no longer claim the Main Box is unaffected: patches loaded into Master can reach Main and existing Boxes, depending on Ruby's copy-on-write state (#52).
- An autoload a Carton defines, such as a lazy Zeitwerk constant, loads in the Carton's Box even when an importer references it first. It used to run in the importer's Box, often the Main Box, or raise `NameError` when the importer used another name. Autoloaded files also go through the Box's `Kernel#require`, so Zeitwerk's `on_load` callbacks and reloading see them (#48).

## [0.2.0] - 2026-10-17

Cartons are now gem-sized or domain-sized units: a file plus the directory named after it. This release also redesigns exports, shares imports across the process, adds gem and Bundler support, and requires Ruby 4.0.7 (#9, #10, #11, #14, #15, #17, #18, #19, #20, #36).

### Breaking

- A Carton is now a file plus the directory named after it, the shape of a gem's `lib/`: `billing.rb` and everything under `billing/`, including Zeitwerk implicit-namespace directories. Importing a file inside a Carton, such as `import 'billing/invoice'`, raises `Carton::ImportError` naming the import to use. It used to load a second copy of the file in its own Box, so its classes did not match the Carton's (#36).
- Carton now requires Ruby 4.0.7 or later, enforced by the gemspec, and Bundler support needs Bundler 4.0.23 or later (#11).
- `export` can be called many times per file, and each call adds to one Export Namespace. A capitalized Symbol exports a constant (`export :Money`), other Symbols export methods (`export :add`, or `export def add ...`), and keywords export plain values. Replace `export add: method(:add)` with `export :add`. A missing name raises `NameError`, and a name exported twice raises `Carton::ExportError` (#9, #19).
- Exported methods forward when called (`exports.add(...)`), while `[]`, `fetch`, and destructuring return the `Method` object. Keyword values are no longer invoked: `export handler: -> {}` makes `exports.handler` return the lambda (#9).
- `export_default` may be called only once per file and cannot be combined with `export`; both raise `Carton::ExportError`. Put other names inside the default value (#20).
- Importing a file with no exports (a Bare Carton) returns a `Carton::Exports` of the constants and top-level helpers it defines, instead of its `Carton::Box`. Importers can no longer `eval`, `require`, or read `load_path` inside another Carton. Helpers are callable directly (`toolbox.helper`), lookups return their `Method` object (`toolbox.fetch(:helper).call`), and constants are read when the import finishes. `Carton::Box` is now a private constant (#17).
- Imports are shared across the process. Each Carton file loads once, and every later `import` or `import_relative` of it returns the same value, so sibling Cartons share classes and Carton state no longer resets per import. A Carton that imports itself raises `Carton::ImportError` (#10).
- `import 'name'` no longer checks the current directory before `$LOAD_PATH`, so results no longer depend on where the app was started. Use an absolute path, `import_relative`, or add the directory to `$LOAD_PATH` (#13).
- `Carton.with_bundle { require 'bundler/setup' }` is replaced by `Carton.setup_bundle`. Pass groups as with `Bundler.setup` (`Carton.setup_bundle(:default, :test)`) and choose a Gemfile with `gemfile:`. Bundler errors raise instead of exiting the process (#11).

### Added

- `import_relative` and absolute `import` accept a gem-shaped directory: `import_relative 'components/billing'` loads `components/billing/lib/billing.rb` with that `lib/` on the Carton's load path (#36).
- `Carton::Error`, the base class of every error Carton raises itself, with `Carton::ImportError` (circular imports, gem version mismatches) and `Carton::ExportError` (repeated or conflicting exports). They replace plain `RuntimeError`s and `ArgumentError`s, and are the same classes in every Box. `Carton::GemfileNotFound` is now a `Carton::Error` (#35).
- `Carton.setup_bundle(*groups, gemfile: nil)` sets up a Carton's own bundle. Without `gemfile:` it searches upward from the calling file for `gems.rb` or `Gemfile`. It clears any stale `BUNDLE_LOCKFILE` and restores all of `ENV` after setup, so a Carton's bundle variables never reach the rest of the process. `Carton::GemfileNotFound` is raised when there is no Gemfile (#11, #12).
- Public RBS signatures in `sig/carton.rbs` ([0b7d16c](https://github.com/dtcristo/carton/commit/0b7d16c6e251931759edbc65f518b11377635f5d)).
- `examples/monorepo`: packages as path gems in one Gemfile, imported by gem name (#33).
- `examples/rails_in_main`: a Rails API app whose domain logic is a Zeitwerk-loaded path-gem Carton (#21, #23).
- `examples/rails_in_cartons`: Rails loaded once in a framework Carton, with models and controllers spread across domain Cartons. The Main Box runs only Rack (#22, #23).
- `examples/master_prelude`: an optional, unsupported hack that loads Active Support's core extensions into Ruby's Master Box so every Carton inherits them (#24).

### Changed

- `export` and `export_default` only declare exports from the imported Entrypoint. Under plain `require`, or in other files a Carton requires, they validate their arguments and do nothing, so Carton-aware files and gems also load with `require` (#18).
- Importing a file from an activated gem activates that gem and its runtime dependencies in the Carton's Box at the caller's versions. When the caller ran Bundler setup, the Box is also restricted to the caller's bundle: every locked gem loads at its locked version, and gems outside the lockfile raise `LoadError` (#14, #15).
- `import`, `import_relative`, `export`, and `export_default` are private Kernel methods, like `require`, so `"str".import(...)` raises `NoMethodError` and objects no longer `respond_to?` them (#8).
- `import 'name'` resolves the feature in the caller's Box and carries only the matching load-path entry into the imported Box, instead of copying the caller's whole `$LOAD_PATH` ([110dfb6](https://github.com/dtcristo/carton/commit/110dfb68c7488e2e32de3e71c01fcecccbc893f8)).
- `RUBY_BOX=1 bundle exec` works, including Gemfiles that evaluate a gemspec. Carton no longer patches RubyGems or Bundler (#11).

### Fixed

- Importing without `RUBY_BOX=1` raises `Carton::ImportError` explaining how to enable Boxes, instead of `NoMethodError` on `nil` (#35).
- A missing `import_relative` target raises `LoadError` instead of loading a same-named feature from the load path (such as the stdlib `json`), and a missing absolute `import` raises `LoadError` instead of `Errno::ENOENT` (#30).
- `export_default` keeps Hash, `nil`, and `false` values as Default Exports instead of treating a Hash as an Export Namespace (#4).
- A gem Carton imported from another Carton's Box gets its dependencies. Activation used to write to the importing Carton's `$LOAD_PATH`, so the gem's `require` of a dependency raised `LoadError` (#15).
- A gem Carton's dependencies load at the caller's versions instead of the newest installed ones. A later import whose caller has different versions activated raises instead of reusing the cached Carton (#14).
- Bare Carton lookup only finds constants and helpers the Entrypoint defines. Keys are no longer evaluated as Ruby expressions, and `key?` no longer calls helpers (#5).
- Hash-rest patterns (`=> { **rest }`) return every Named Export, or every member of a Bare Carton's Public Surface, instead of an empty hash (#6).

## [0.1.0] - 2026-04-16

Initial release ([9925397](https://github.com/dtcristo/carton/commit/99253978dd73b70698341d04314e3ccf86b37c16)).

[Unreleased]: https://github.com/dtcristo/carton/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/dtcristo/carton/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/dtcristo/carton/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/dtcristo/carton/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/dtcristo/carton/releases/tag/v0.1.0
