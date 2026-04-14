# Complex example

Multi-package example showing the library directly: explicit load-path setup, a bundled single export, a named export loaded by name, and a destructured import.

## Packages

| Package | Purpose |
| --- | --- |
| `main` | explicit feature tour of the library |
| `adventure` | bundled package imported by absolute path |
| `quest` | plain package imported by name, with an internal `import_relative` |
| `loot` | package that demonstrates a conflicting `dotenv` version via subprocess |

`main.rb` keeps the load-path setup and bundled `import` explicit on purpose so the example reads like a direct Package feature tour.

## Why `loot` still uses a subprocess

One package-local bundle can be activated from an unbundled parent today. A second conflicting bundle in the same process is not reliable yet, so `loot` still loads its `dotenv` data in a subprocess. That is tracked in [../../TODO.md](../../TODO.md).

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
