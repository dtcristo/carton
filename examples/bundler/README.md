# Bundler example

Small app-shaped example showing:

- a Carton that runs Bundler setup before requiring `bigdecimal`
- a Carton that forwards to an Imported Carton with its own Bundler setup
- a support gem resolved by the app bundle and imported as a Carton

## Cartons

| Carton | `bigdecimal` | How it loads |
| --- | --- | --- |
| `math_helper` | `4.1.1` | imported by name from `main.rb`, uses `require 'bigdecimal'` |
| `billing` | none directly | imported by name from `main.rb`; `import_relative`s `rounding` |
| `rounding` | `3.3.1` | Imported Carton with its own Bundler setup; uses `import 'bigdecimal'` |
| `cartoned_gem` | none | support gem resolved by the top-level bundle, then imported by name |

`main.rb` keeps the Carton `lib/` load-path setup explicit so
`import 'math_helper'` and `import 'billing'` are easy to follow. The support
gem exercises the boxed path-gem boundary.

## Run

```sh
RUBY_BOX=1 ruby examples/bundler/main.rb
```

The integration suite also uses this example as its path-gem and nested-bundle
regression: separate Cartons keep their gem versions, the path gem imports
cleanly, and the Main Box's activated gems stay unchanged.
