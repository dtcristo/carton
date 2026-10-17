# Bundler example

Small app-shaped example showing:

- a Carton that runs Bundler setup before requiring `bigdecimal`
- a Carton that forwards to an Imported Carton with its own Bundler setup
- a support gem resolved by the app bundle and imported as a Carton

## Cartons

| Carton | `bigdecimal` | How it loads |
| --- | --- | --- |
| `math_helper` | `4.1.1` | imported by its directory from `main.rb`; uses `require 'bigdecimal'` |
| `billing` | none directly | imported by its directory from `main.rb`; imports `rounding` by its directory |
| `rounding` | `3.3.1` | Imported Carton with its own Bundler setup; uses `import 'bigdecimal'` |
| `cartoned_gem` | none | support gem resolved by the top-level bundle, then imported by name |

Each local Carton is a gem-shaped directory, such as
`cartons/billing/lib/billing.rb`, so `import_relative 'cartons/billing'`
imports it without touching `$LOAD_PATH`. The support gem exercises the boxed
path-gem boundary.

## Run

```sh
RUBY_BOX=1 ruby examples/bundler/main.rb
```

The integration suite also uses this example as its path-gem and nested-bundle
regression: separate Cartons keep their gem versions, the path gem imports
cleanly, and the Main Box's activated gems stay unchanged.
