# Design

## Goal

Keep the library small: a thin wrapper around `Ruby::Box` that makes isolated file-to-file imports feel like part of Ruby.

## Main pieces

| File | Role |
| --- | --- |
| `lib/package.rb` | Entry point, version guard, `Package.with_bundle`, and internal wiring |
| `lib/package/kernel_patch.rb` | Adds global `import`, `import_relative`, and `export` |
| `lib/package/runtime.rb` | Builds boxes, resolves targets, runs imports, and extracts exports |
| `lib/package/box.rb` | Box-specific helpers for requiring files, managing export state, and inheriting safe load paths |
| `lib/package/exports.rb` | Wraps named exports in a module-like namespace |
| `lib/package/export_methods.rb` | Shared `[]`, `fetch`, `fetch_values`, `values_at`, `key?`, and destructuring support |

## Import flow

1. `import` or `import_relative` delegates to `Package::Runtime.import`.
2. A fresh `Package::Box` is created for that import.
3. The package entrypoint (`lib/package.rb`) is required inside the box so the box has `export`, `import`, and `import_relative`.
4. The target file is resolved either from the caller's base directory or from the current box's `$LOAD_PATH`.
5. The target file is required inside the box.
6. If the file called `export`, the exported value is returned.
7. If the export was a hash, it is wrapped in `Package::Exports`.
8. If there was no export, the box itself is returned.

Every import creates a fresh box. There is no module cache at the Package layer.

## Export model

There are three return shapes:

- single export: the exported object itself
- named exports: `Package::Exports`
- no export: `Package::Box`

`Package::Exports` exposes capitalized keys as constants and lowercase keys as singleton methods. Both `Package::Exports` and `Package::Box` share the same small fetch/deconstruction API through `ExportMethods`.

## Load path model

Ruby::Box creates new user boxes from the root box, not from the current caller box. In `box.c`, each new box starts by duplicating the root box's `load_path` and `loaded_features`, and `require` resolves against the loading box's local `$LOAD_PATH` / `$LOADED_FEATURES`.

Package therefore re-inherits the parent box's non-gem load paths manually so local package directories can still be resolved by name across nested imports.

The current filter deliberately tries to avoid leaking gem paths from a parent import chain into child boxes:

- RubyGems paths are filtered
- common Bundler vendor paths are filtered
- local, non-gem package paths are preserved

This is why the examples add sibling `lib/` directories to `$LOAD_PATH` explicitly before using `import 'name'`.

## Bundler model

The current implementation works best when a package bundle is selected before its entry file is evaluated. In practice that means selecting `BUNDLE_GEMFILE` around the `import` call for that package; `Package.with_bundle` is the small wrapper for that handoff.

This keeps one package-local bundle isolated from the caller, but current limitations remain:

- a parent already running under Bundler is not a reliable place to import a child package with its own bundle
- switching between conflicting bundles in one process is not reliable today
- the complex example uses a subprocess for the conflicting `loot` bundle for that reason

The problem is not that Bundler has special C code mutating every box at once. Bundler and RubyGems do their activation work in Ruby:

- `Bundler::SharedHelpers#find_gemfile` reads `ENV['BUNDLE_GEMFILE']`
- `Bundler::Runtime#setup` calls `clean_load_path`, `replace_entrypoints`, `mark_loaded`, and `Gem.add_to_load_path`
- RubyGems activation checks and writes `Gem.loaded_specs`

What matters under `Ruby::Box` is which of those pieces are box-local. In practice:

- `$LOAD_PATH` stays box-local; activating a bundle in an imported box does not inject its gem lib paths into the caller box
- `Gem.loaded_specs` is still shared across boxes in practice; the same hash object is visible in the caller and imported box

That shared activation state is why a second box can see a gem version activated by the first one even though its own `$LOAD_PATH` is separate. In local probes, activating `dotenv 3.2.0` in one box caused a second box targeting `dotenv ~> 2.0` to fail its Bundler activation and then crash under Ruby 4.0 + `Ruby::Box`.

See [TODO.md](TODO.md) for the upstream work that would help.

## Why the complex example stays explicit

The complex example keeps load-path setup and bundled imports visible in `main.rb` on purpose. It is meant to demonstrate Package directly, not hide the mechanics behind another layer.
