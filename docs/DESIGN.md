# Design

## Goal

Keep the library small: a thin wrapper around `Ruby::Box` that makes isolated file-to-file imports feel like part of Ruby.

## Main pieces

| File | Role |
| --- | --- |
| `lib/carton.rb` | Entry point, version guard, and internal wiring |
| `lib/carton/bundler.rb` | `Carton.with_bundle` plus caller-file bundle discovery |
| `lib/carton/rubygems.rb` | temporary compatibility patch behind `Carton.bootstrap_rubygems!` |
| `lib/carton/kernel_patch.rb` | Adds global `import`, `import_relative`, `export_default`, and `export` |
| `lib/carton/runtime.rb` | Builds boxes, resolves targets, runs imports, and extracts exports |
| `lib/carton/box.rb` | Box-specific helpers for requiring files, managing export state, seeding an imported feature's load path, and keeping the RubyGems cleanup hack out of the generic runtime path |
| `lib/carton/exports.rb` | Wraps named exports in a module-like namespace |
| `lib/carton/export_methods.rb` | Shared `[]`, `fetch`, `fetch_values`, `values_at`, `key?`, and destructuring support |

## Import flow

1. `import` or `import_relative` delegates to `Carton::Runtime.import`.
2. A fresh `Carton::Box` is created for that import.
3. The carton entrypoint (`lib/carton.rb`) is required inside the box so the box has `export`, `import`, and `import_relative`.
4. The target file is resolved either from the caller's base directory or from the caller box's `$LOAD_PATH`.
5. If the target was found by name, Carton seeds only that matching load-path entry into the new box.
6. The target file is required inside the box.
7. If the file called `export_default` or `export`, the exported value is returned.
8. If the export was a hash, it is wrapped in `Carton::Exports`.
9. If there was no export, the box itself is returned.

If the imported file bootstrapped RubyGems, `Carton::Box` restores the caller's
`Gem.loaded_specs` view after the import. Supported-stack probes show the
registry is already box-local, so this compatibility code should disappear
once path-bundle integration passes without it.

Every import creates a fresh box. There is no module cache at the Carton layer.

## Export model

There are three return shapes:

- single export: the exported object itself
- named exports: `Carton::Exports`
- no export: `Carton::Box`

`export_default` is the explicit single-export form. `export` is the named-export form and only accepts keyword arguments. `Carton::Exports` exposes capitalized keys as constants and lowercase keys as singleton methods. Both `Carton::Exports` and `Carton::Box` share the same small fetch/deconstruction API through `ExportMethods`.

## Load path model

Ruby::Box creates new user boxes from the root box, not from the current caller box. In `box.c`, each new box starts by duplicating the root box's `load_path` and `loaded_features`, and `require` resolves against the loading box's local `$LOAD_PATH` / `$LOADED_FEATURES`.

Carton therefore does not copy the caller's whole load path forward anymore. Instead it resolves the feature name in the caller box first, then carries only the matching load-path entry into the new box if the imported feature needs that root for its own nested `require` calls.

This is why the examples add sibling `lib/` directories to `$LOAD_PATH` explicitly before using `import 'name'`.

## Bundler model

The current bundled-carton model is explicit inside the carton entry file:

```ruby
Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }
```

A top-level app that only needs its own bundle, like `examples/bundler/main.rb`,
can stay lighter and use plain `Carton.with_bundle { require 'bundler/setup' }`.
The explicit RubyGems bootstrap is for bundled cartons loaded into fresh boxes.
`Carton.with_bundle` also installs a current-box RubyGems path-gem compatibility
patch. Boxed path-gem setup remains incomplete upstream.

Current limitations:

- `RUBY_BOX=1 bundle exec` fails during prelude before application code starts,
- boxed path gems hit Ruby method-dispatch failures,
- Carton still carries RubyGems compatibility code that current registry
  isolation should eventually make unnecessary.

The problem is not that Bundler has special C code mutating every box at once. Bundler and RubyGems do their activation work in Ruby:

- `Bundler::SharedHelpers#find_gemfile` reads `ENV['BUNDLE_GEMFILE']`
- `Bundler::SharedHelpers#default_lockfile` reads `ENV['BUNDLE_LOCKFILE']`
- `Bundler::Runtime#setup` calls `clean_load_path`, `replace_entrypoints`, `mark_loaded`, and `Gem.add_to_load_path`
- RubyGems activation checks and writes `Gem.loaded_specs`

On the supported stack, `$LOAD_PATH`, `Gem.loaded_specs`, and
`Gem::Specification.specification_record` stay box-local. Conflicting non-path
bundles work in separate boxes, including beneath an already-bundled main box.

The remaining path-gem failures are method-lookup problems across box class
extensions: symbol-proc dispatch misses a boxed method, and boxed `super` can
select `BasicObject#initialize` instead of `Gem::Dependency#initialize`.

See [HOW_GEMS_WORK.md](HOW_GEMS_WORK.md) and [HOW_BOXES_WORK.md](HOW_BOXES_WORK.md) for the deeper runtime model, plus [RUBYGEMS_UPSTREAM.md](RUBYGEMS_UPSTREAM.md) and [RUBY_UPSTREAM.md](RUBY_UPSTREAM.md) for the minimal upstream work.
