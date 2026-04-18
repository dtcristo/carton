# Design

## Goal

Keep the library small: a thin wrapper around `Ruby::Box` that makes isolated file-to-file imports feel like part of Ruby.

## Main pieces

| File | Role |
| --- | --- |
| `lib/carton.rb` | Entry point, version guard, `Carton.with_bundle`, and internal wiring |
| `lib/carton/kernel_patch.rb` | Adds global `import`, `import_relative`, `export_default`, and `export` |
| `lib/carton/runtime.rb` | Builds boxes, resolves targets, runs imports, and extracts exports |
| `lib/carton/box.rb` | Box-specific helpers for requiring files, managing export state, and inheriting safe load paths |
| `lib/carton/exports.rb` | Wraps named exports in a module-like namespace |
| `lib/carton/export_methods.rb` | Shared `[]`, `fetch`, `fetch_values`, `values_at`, `key?`, and destructuring support |

## Import flow

1. `import` or `import_relative` delegates to `Carton::Runtime.import`.
2. A fresh `Carton::Box` is created for that import.
3. The carton entrypoint (`lib/carton.rb`) is required inside the box so the box has `export`, `import`, and `import_relative`.
4. The target file is resolved either from the caller's base directory or from the current box's `$LOAD_PATH`.
5. The target file is required inside the box.
6. If the file called `export_default` or `export`, the exported value is returned.
7. If the export was a hash, it is wrapped in `Carton::Exports`.
8. If there was no export, the box itself is returned.

Every import creates a fresh box. There is no module cache at the Carton layer.

## Export model

There are three return shapes:

- single export: the exported object itself
- named exports: `Carton::Exports`
- no export: `Carton::Box`

`export_default` is the explicit single-export form. `export` is the named-export form and only accepts keyword arguments. `Carton::Exports` exposes capitalized keys as constants and lowercase keys as singleton methods. Both `Carton::Exports` and `Carton::Box` share the same small fetch/deconstruction API through `ExportMethods`.

## Load path model

Ruby::Box creates new user boxes from the root box, not from the current caller box. In `box.c`, each new box starts by duplicating the root box's `load_path` and `loaded_features`, and `require` resolves against the loading box's local `$LOAD_PATH` / `$LOADED_FEATURES`.

Carton therefore re-inherits the parent box's non-gem load paths manually so local carton directories can still be resolved by name across nested imports.

The current filter deliberately tries to avoid leaking gem paths from a parent import chain into child boxes:

- RubyGems paths are filtered
- common Bundler vendor paths are filtered
- local, non-gem carton paths are preserved

This is why the examples add sibling `lib/` directories to `$LOAD_PATH` explicitly before using `import 'name'`.

## Bundler model

The current implementation works best when a carton bundle is selected before its entry file is evaluated. In practice that means selecting `BUNDLE_GEMFILE` around the `import` call for that carton; `Carton.with_bundle` is the small wrapper for that handoff.

This keeps one carton-local bundle isolated from the caller, but current limitations remain:

- a parent already running under Bundler is not a reliable place to import a child carton with its own bundle
- switching between conflicting bundles in one process is not reliable today
- the complex example uses a subprocess for the conflicting `loot` bundle for that reason

The problem is not that Bundler has special C code mutating every box at once. Bundler and RubyGems do their activation work in Ruby:

- `Bundler::SharedHelpers#find_gemfile` reads `ENV['BUNDLE_GEMFILE']`
- `Bundler::Runtime#setup` calls `clean_load_path`, `replace_entrypoints`, `mark_loaded`, and `Gem.add_to_load_path`
- RubyGems activation checks and writes `Gem.loaded_specs`

What matters under `Ruby::Box` is which of those pieces are box-local. In practice:

- `$LOAD_PATH` stays box-local; activating a bundle in an imported box does not inject its gem lib paths into the caller box
- `Gem.loaded_specs` is still shared across boxes in practice unless it is explicitly replaced inside the box

Duplicating `Gem.loaded_specs` inside an imported box was enough to keep a single bundled import from leaking back into the caller box, but it was still not enough to make two conflicting bundles coexist. Bundler also rewrites RubyGems entrypoints and spec state through code paths such as `replace_entrypoints`, `stub_rubygems`, `Gem::Specification.all = ...`, and `Gem.clear_paths`.

That shared activation state is why a second box can see a gem version activated by the first one even though its own `$LOAD_PATH` is separate. In local probes, activating `dotenv 3.2.0` in one box caused a second box targeting `dotenv ~> 2.0` to fail its Bundler activation and then crash under Ruby 4.0 + `Ruby::Box`.

See [HOW_GEMS_WORK.md](HOW_GEMS_WORK.md) and [HOW_BOXES_WORK.md](HOW_BOXES_WORK.md) for the deeper runtime model, plus [RUBYGEMS_UPSTREAM.md](RUBYGEMS_UPSTREAM.md) and [RUBY_UPSTREAM.md](RUBY_UPSTREAM.md) for the minimal upstream work.

## Why the complex example stays explicit

The complex example keeps load-path setup and bundled imports visible in `main.rb` on purpose. It is meant to demonstrate Carton directly, not hide the mechanics behind another layer.
