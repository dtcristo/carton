# Complex example

Multi-carton example showing the library directly: explicit load-path setup, a bundled single export loaded by name, a plain carton loaded by name, and a boxed gem import.

## Cartons

| Carton | Purpose |
| --- | --- |
| `main` | explicit feature tour of the library |
| `adventure` | bundled carton imported by name |
| `quest` | plain carton imported by name |
| `loot` | bundled carton that imports `dotenv` into its own box |

`main.rb` keeps the load-path setup and bundled import explicit on purpose so the example reads like a direct Carton feature tour. Both bundled cartons call `Carton.bootstrap_rubygems!` inside the box, then wrap `require 'bundler/setup'` in `Carton.with_bundle`. `loot` also shows that `import 'dotenv'` can wrap a gem that does not export anything into its own box.

## Run

```sh
RUBY_BOX=1 bundle exec rake example:complex
```

Or manually:

```sh
cd examples/complex/cartons/adventure && BUNDLE_GEMFILE=Gemfile bundle install
cd ../loot && BUNDLE_GEMFILE=Gemfile bundle install
cd ../../..
RUBY_BOX=1 ruby examples/complex/main.rb
```
