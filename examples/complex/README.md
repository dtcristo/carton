# Complex example

Multi-package example showing isolated imports, named exports, load-path based imports, and package-local Bundler.

## Packages

| Package | Purpose |
| --- | --- |
| `main` | root script that adds sibling `lib/` dirs to `$LOAD_PATH` |
| `adventure` | package with its own bundle (`dotenv`, `colorize`, `chronic`) |
| `quest` | pure-Ruby package imported by name |
| `loot` | package that demonstrates a conflicting `dotenv` version via subprocess |

## Boilerplate helpers

`support/package_support.rb` keeps the example terse:

- `add_package_libs` / `add_sibling_package_libs` manage local package load paths
- `import_with_bundle` wraps the reliable current Bundler pattern: set `BUNDLE_GEMFILE` around `import`
- `load_dotenv_payload` handles the subprocess workaround for the conflicting `loot` bundle

## Why `loot` still uses a subprocess

One package-local bundle can be activated from an unbundled parent today. A second conflicting bundle in the same process is not reliable yet, and attempts to force the switch hit Bundler/Ruby::Box limitations. That is tracked in [../../TODO.md](../../TODO.md).

## Run

```sh
RUBY_BOX=1 bundle exec rake example:complex
```

Or manually:

```sh
cd examples/complex && BUNDLE_GEMFILE=Gemfile bundle install
cd packages/adventure && BUNDLE_GEMFILE=Gemfile bundle install
cd ../loot && BUNDLE_GEMFILE=Gemfile bundle install
cd ../../..
RUBY_BOX=1 ruby examples/complex/main.rb
```
