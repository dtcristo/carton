# Complex example

Multi-package example showing the library directly: explicit load-path setup, a bundled single export loaded by name, a plain package loaded by name, and a destructured import.

## Packages

| Package | Purpose |
| --- | --- |
| `main` | explicit feature tour of the library |
| `adventure` | bundled package imported by name |
| `quest` | plain package imported by name |
| `loot` | package that demonstrates a conflicting `dotenv` version via subprocess |

`main.rb` keeps the load-path setup and bundled import explicit on purpose so the example reads like a direct Package feature tour. `Package.with_bundle` shortens the `BUNDLE_GEMFILE` handoff, but it is still the same Bundler constraint under the hood.

## Why `loot` still uses a subprocess

One package-local bundle can be activated from an unbundled parent today. The trouble starts when another box tries to activate a conflicting version: box-local `$LOAD_PATH` is not enough because RubyGems activation state is still shared. `loot` therefore loads its `dotenv` data in a subprocess and selects its Gemfile there instead of using `Package.with_bundle` during the import itself. That is tracked in [../../TODO.md](../../TODO.md).

## Run

```sh
RUBY_BOX=1 bundle exec rake example:complex
```

Or manually:

```sh
cd examples/complex/packages/adventure && BUNDLE_GEMFILE=Gemfile bundle install
cd ../loot && BUNDLE_GEMFILE=Gemfile bundle install
cd ../../..
RUBY_BOX=1 ruby examples/complex/main.rb
```
