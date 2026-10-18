# Bundler example

This example shows Carton Bundles across Imports. Use [gems](../gems/README.md) for explicit version selection without Bundler, or [plugins](../plugins/README.md) for a host whose plugins require incompatible gem APIs. Here the focus is how each Imported Carton loads its gems:

- a Carton that runs Bundler setup before requiring `bigdecimal`
- a Carton that imports another Carton with its own Carton Bundle
- a support gem resolved by the app bundle and imported as a Carton

## Cartons

| Carton | `bigdecimal` | How it loads |
| --- | --- | --- |
| `math_helper` | `4.1.1` | imported by its directory from `main.rb`; uses `require 'bigdecimal'` |
| `billing` | none directly | imported by its directory from `main.rb`; imports `rounding` by its directory |
| `rounding` | `3.3.1` | `billing`'s Imported Carton and the app's Transitive Carton; sets up a Carton Bundle and uses `import 'bigdecimal'` |
| `cartoned_gem` | none | support gem resolved by the top-level bundle, then imported by name |

Each local Carton has a Gem-shaped Directory, such as `cartons/billing/` with Entrypoint `lib/billing.rb`, so `import_relative 'cartons/billing'` imports it without touching `$LOAD_PATH`. The support gem exercises the Gem Carton boundary.

## Run

From the repository root:

```sh
bundle exec rake example:bundler
```

After the task installs the app bundle and Carton Bundles:

```sh
RUBY_BOX=1 ruby examples/bundler/main.rb
```

The integration suite also uses this example as its path-gem and Carton Bundle regression: separate Cartons keep their gem versions, the path gem imports cleanly, and the Main Box's activated gems stay unchanged.
