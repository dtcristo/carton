# Bundler example

Bundled multi-carton example showing three boxed bundles plus a carton-aware gem.

## Cartons

| Carton | `bigdecimal` | How it loads |
| --- | --- | --- |
| `bigdecimal4` | `4.1.1` | imported by name from `main.rb`, uses `require 'bigdecimal'` |
| `bigdecimal3` | `3.3.1` | imported by name from `main.rb`, uses `import 'bigdecimal'` |
| `bigdecimal2` | `2.0.3` | transient carton imported from `bigdecimal3` with `import_relative` |
| `gem_in_carton` | `2.0.3` | imported by name from `main.rb` through the top-level bundle |

`main.rb` keeps both the explicit local-carton load-path setup and the top-level bundle for `gem_in_carton` visible on purpose. After Bundler resolves the path gem, `main.rb` explicitly exposes that gem's `lib/` directory on `$LOAD_PATH` before importing it by name. Each carton or gem still bootstraps RubyGems and loads its own bundle inside the box. The shared example task also prepares a tiny compatibility patch for `bigdecimal 2.0.3`, which does not build cleanly on Ruby 4.0.2 as published.

`main.rb` ends with `Process.exit!(0)` as a temporary workaround for the current Ruby 4.0.2 `Ruby::Box` teardown crash.

## Run

```sh
RUBY_BOX=1 bundle exec rake example:bundler
```
