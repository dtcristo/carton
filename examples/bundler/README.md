# Bundler example

Small app-shaped example showing:

- a bundled carton that `require`s `bigdecimal`
- a plain carton that forwards to a transient bundled carton
- a support gem resolved by the app bundle and imported as a carton

## Cartons

| Carton | `bigdecimal` | How it loads |
| --- | --- | --- |
| `math_helper` | `4.1.1` | imported by name from `main.rb`, uses `require 'bigdecimal'` |
| `billing` | none directly | imported by name from `main.rb`, plain carton that `import_relative`s `rounding` |
| `rounding` | `3.3.1` | transient bundled carton, uses `import 'bigdecimal'` |
| `cartoned_gem` | none | support gem resolved by the top-level bundle, then imported by file path |

`main.rb` keeps the carton `lib/` load-path setup explicit so `import 'math_helper'` and `import 'billing'` are easy to follow. The support gem comes from the app bundle instead: Bundler resolves the path gem, then `main.rb` imports that gem's entry file directly from the resolved gem path.

## Run

```sh
RUBY_BOX=1 bundle exec rake example:bundler
```
