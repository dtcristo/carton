# Examples

Start with [minimal](minimal/README.md). Each example is a separate program; similar names such as Billing and Shipping do not refer to shared code between examples.

## Choose an example

| Question | Example |
| --- | --- |
| How do I draw a boundary and export a module? | [minimal](minimal/README.md), with separate invalid code for `carton check` and RBS for Steep |
| What can an Import return? How do I load existing Ruby? | [exports](exports/README.md): Hashes, callables, Bare Carton Helpers, and pattern matching |
| How do Cartons share one app lockfile? | [monorepo](monorepo/README.md): path gems, declared dependencies, and unit and integration tests |
| How does a Carton use the app's database or services? | [dependency_injection](dependency_injection/README.md): a checkout with host adapters and fakes |
| How do I use Carton with Rails today? | [rails_in_main](rails_in_main/README.md): Rails stays in Main; a plain-Ruby domain runs in a Carton |
| How do I host plugins with conflicting gems? | [plugins](plugins/README.md): Dynamic Imports, a shared interface, Carton Bundles, and a contained builtin patch |
| How do I select gem versions without Bundler? | [gems](gems/README.md): explicit RubyGems activation in two Cartons |
| How do Carton Bundles work across Imports? | [bundler](bundler/README.md): Gem-shaped Directories, a Transitive Carton, a Bare Carton gem, and a path gem |
| How do autoloading and reloading interact with imports? | [zeitwerk](zeitwerk/README.md): loaders per Box, lazy namespaces, and references that stay stale after reload |
| Can Rails itself live inside Cartons? | [rails_in_cartons](rails_in_cartons/README.md), experimental: shared framework classes and explicit registration |

`gems`, `bundler`, and `plugins` all use conflicting bigdecimal versions, but teach different loading choices. Use `gems` for the shortest version-isolation demonstration, `bundler` for setup details, and `plugins` for an application of them. Keeping each runnable on its own makes the boundary visible without reading code from another example.

Unsupported and private-runtime experiments live in [spikes/](../spikes/README.md). Both Rails integrations remain examples; the separate Rails reloading experiment uses the Rails-in-Cartons app as a fixture.

## Run

Use Ruby 4.0.7+ and Bundler 4.0.20+. From the repository root, install the development bundle once, then choose a task:

```sh
bundle install
bundle exec rake example:minimal
bundle exec rake example:plugins
bundle exec rake examples          # every example
bundle exec rake                   # tests, RuboCop, and every example
```

Each `example:<name>` task installs all of that example's bundles, enables Boxes, runs `main.rb`, then runs any `test/**/*_test.rb` files in separate processes. The `gems` task installs its two bigdecimal versions directly. Initial setup may need network access and native build tools.

After setup, every example also runs directly:

```sh
RUBY_BOX=1 ruby examples/<name>/main.rb
```

`Carton.setup_bundle` activates an installed bundle; it does not install missing gems. For a fresh checkout, use the Rake task first, especially for examples with several Gemfiles. The plugin tests have their own bundle under `plugins/test/`, while the host itself needs none.

## Editing code

Each Carton loads once per process. These `main.rb` programs run and exit, so rerun them after editing. A long-running application must restart to pick up changed Cartons. Keeping the Export module and reloading code in its Interior with Zeitwerk is possible, but existing references to classes and instances stay stale; see [Zeitwerk reloading](zeitwerk/README.md#reloading).
