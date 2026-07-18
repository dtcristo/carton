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
| `cartoned_gem` | none | support gem resolved by the top-level bundle, then imported by name |

`main.rb` keeps the carton `lib/` load-path setup explicit so
`import 'math_helper'` and `import 'billing'` are easy to follow. The support
gem exercises the unresolved boxed path-gem boundary.

## Current status

This example is the repository-level path-gem regression. It does not currently
complete: boxed Bundler setup is blocked by Ruby method dispatch, and boxed
`bundle exec` fails earlier during prelude.
