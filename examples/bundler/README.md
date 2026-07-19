# Bundler example

Small app-shaped example showing:

- a Carton that runs Bundler setup before requiring `bigdecimal`
- a Carton that forwards to an Imported Carton with its own Bundler setup
- a support gem resolved by the app bundle and imported as a carton

## Cartons

| Carton | `bigdecimal` | How it loads |
| --- | --- | --- |
| `math_helper` | `4.1.1` | imported by name from `main.rb`, uses `require 'bigdecimal'` |
| `billing` | none directly | imported by name from `main.rb`; `import_relative`s `rounding` |
| `rounding` | `3.3.1` | Imported Carton with its own Bundler setup; uses `import 'bigdecimal'` |
| `cartoned_gem` | none | support gem resolved by the top-level bundle, then imported by name |

`main.rb` keeps the carton `lib/` load-path setup explicit so
`import 'math_helper'` and `import 'billing'` are easy to follow. The support
gem exercises the boxed path-gem boundary.

## Current status

This example is the repository-level path-gem and nested-bundle regression. On
Ruby 4.0.6 it passes: separate Cartons keep their gem versions, the app path
gem imports cleanly, and Main Box activation state stays unchanged.
`RUBY_BOX=1 bundle exec` with a gemspec remains an upstream prelude failure.
