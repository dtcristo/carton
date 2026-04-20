# Design

## Goal

Keep the library small: a thin wrapper around `Ruby::Box` that makes isolated file-to-file imports feel like part of Ruby.

## Main pieces

| File | Role |
| --- | --- |
| `lib/carton.rb` | Entry point, version guard, and internal wiring |
| `lib/carton/bundler.rb` | `Carton.with_bundle` plus caller-file bundle discovery |
| `lib/carton/rubygems.rb` | temporary boxed RubyGems/Bundler patch behind `Carton.bootstrap_rubygems!` |
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
`Gem.loaded_specs` view after the import. That hack is intentionally kept in the
boxed helper layer rather than the generic runtime.

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

This keeps one carton-local bundle isolated from the caller, but current limitations remain:

- bundled child cartons work best from an unbundled parent process
- `Carton.with_bundle` scopes `BUNDLE_GEMFILE` and clears stale `BUNDLE_LOCKFILE`, but a parent already running under `bundle exec` is still not a supported activation environment
- `Carton::Runtime.import` still snapshots/restores `Gem.loaded_specs` around bootstrapped boxed imports because RubyGems activation state can leak back into the caller otherwise

The problem is not that Bundler has special C code mutating every box at once. Bundler and RubyGems do their activation work in Ruby:

- `Bundler::SharedHelpers#find_gemfile` reads `ENV['BUNDLE_GEMFILE']`
- `Bundler::SharedHelpers#default_lockfile` reads `ENV['BUNDLE_LOCKFILE']`
- `Bundler::Runtime#setup` calls `clean_load_path`, `replace_entrypoints`, `mark_loaded`, and `Gem.add_to_load_path`
- RubyGems activation checks and writes `Gem.loaded_specs`

What matters under `Ruby::Box` is which of those pieces are box-local. In practice:

- `$LOAD_PATH` stays box-local; activating a bundle in an imported box does not inject its gem lib paths into the caller box
- `Gem.loaded_specs` is still shared across boxes in practice unless it is explicitly replaced inside the box

Duplicating and redefining the small RubyGems runtime surface inside an imported box is enough for Carton to run conflicting bundled cartons from an unbundled parent, but it is still not enough to make an already-bundled parent process reliable. Bundler also rewrites RubyGems entrypoints and spec state through code paths such as `replace_entrypoints`, `stub_rubygems`, `Gem::Specification.all = ...`, and `Gem.clear_paths`.

That shared activation state is why a second box can see a gem version activated by the first one even though its own `$LOAD_PATH` is separate. In local probes, activating `dotenv 3.2.0` in one box caused a second box targeting `dotenv ~> 2.0` to fail its Bundler activation and then crash under Ruby 4.0 + `Ruby::Box`.

See [HOW_GEMS_WORK.md](HOW_GEMS_WORK.md) and [HOW_BOXES_WORK.md](HOW_BOXES_WORK.md) for the deeper runtime model, plus [RUBYGEMS_UPSTREAM.md](RUBYGEMS_UPSTREAM.md) and [RUBY_UPSTREAM.md](RUBY_UPSTREAM.md) for the minimal upstream work.

## Why the bundler example stays explicit

The bundler example keeps load-path setup, the top-level bundle that resolves
`cartoned_gem`, and the bundled imports visible in `main.rb` on purpose. It is
meant to demonstrate Carton directly, not hide the mechanics behind another
layer.
