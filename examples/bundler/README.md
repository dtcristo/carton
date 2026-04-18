# Bundler example

Bundled multi-carton example showing two cartons imported by `main.rb`, one transient bundled dependency, and a supporting path gem.

## Cartons

| Carton | `bigdecimal` | How it loads |
| --- | --- | --- |
| `adventure` | `4.1.1` | imported by name from `main.rb`, uses `require 'bigdecimal'` |
| `quest` | none directly | imported by name from `main.rb`, plain carton that `import_relative`s `loot` |
| `loot` | `3.3.1` | transient bundled carton, uses `import 'bigdecimal'` |
| `gem_in_carton` | `3.3.1` | support gem loaded by name from the top-level bundle |

`main.rb` keeps both the explicit local-carton load-path setup and the top-level bundle for `gem_in_carton` visible on purpose. After Bundler resolves the path gem, `main.rb` explicitly exposes that gem's `lib/` directory on `$LOAD_PATH` before importing it by name. `adventure` and `loot` bootstrap RubyGems and load their own bundles inside the box, while `quest` stays plain and just forwards to `loot`.

`main.rb` ends with `Process.exit!(0)` as a temporary workaround for the current Ruby 4.0.2 `Ruby::Box` teardown crash.

## Run

```sh
RUBY_BOX=1 bundle exec rake example:bundler
```
