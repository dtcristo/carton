# Design

## Goal

Keep the library small: a thin wrapper around `Ruby::Box` that makes isolated file-to-file imports feel closer to ESM-style modules.

## Main pieces

| File | Role |
| --- | --- |
| `lib/package.rb` | Entry point, version guard, and internal wiring |
| `lib/package/kernel_patch.rb` | Adds global `import`, `import_relative`, and `export` |
| `lib/package/runtime.rb` | Builds boxes, resolves targets, runs imports, and extracts exports |
| `lib/package/box.rb` | Box-specific helpers for requiring files, managing export state, and inheriting safe load paths |
| `lib/package/exports.rb` | Wraps named exports in a module-like namespace |
| `lib/package/export_methods.rb` | Shared `fetch`, `fetch_values`, and destructuring support |

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

Imports inherit the parent box's non-gem load paths so local package directories can still be resolved by name.

The current filter deliberately tries to avoid leaking gem paths from a parent import chain into child boxes:

- RubyGems paths are filtered
- common Bundler vendor paths are filtered
- local, non-gem package paths are preserved

This is why the examples add sibling `lib/` directories to `$LOAD_PATH` explicitly before using `import('name')`.

## Bundler model

The current implementation works best when a package bundle is selected before its entry file is evaluated. In practice that means setting `BUNDLE_GEMFILE` around the `import` call for that package.

This keeps one package-local bundle isolated from the caller, but current limitations remain:

- a parent already running under Bundler is not a reliable place to import a child package with its own bundle
- switching between conflicting bundles in one process is not reliable today
- the complex example uses a subprocess for the conflicting `loot` bundle for that reason

Those constraints come from the interaction between `Ruby::Box`, `$LOAD_PATH`, `$LOADED_FEATURES`, and Bundler's process-wide environment and RubyGems hooks. See [TODO.md](TODO.md) for the upstream work that would help.

## Why the examples have helper glue

The example helper in `examples/complex/support/package_support.rb` is intentionally example-specific. It keeps the public library surface small while the correct Bundler ergonomics are still being explored.
