# Design

## Goal

Keep the library small: a thin wrapper around `Ruby::Box` that makes isolated file-to-file imports feel like part of Ruby.

## Main pieces

| File | Role |
| --- | --- |
| `lib/carton.rb` | Entry point and internal wiring |
| `lib/carton/bundler.rb` | `Carton.with_bundle` plus caller-file bundle discovery |
| `lib/carton/kernel_patch.rb` | Adds global `import`, `import_relative`, `export_default`, and `export` |
| `lib/carton/import_cache.rb` | Process-wide import cache shared by every Box |
| `lib/carton/runtime.rb` | Builds boxes, resolves targets, runs imports, and extracts exports |
| `lib/carton/box.rb` | Box-specific helpers for requiring files, holding and resetting the current Export Declaration, and seeding an imported feature's load path |
| `lib/carton/export_declaration.rb` | Owns absence, uniqueness, kind, snapshotting, and Public Surface conversion for an Export Declaration |
| `lib/carton/exports.rb` | Wraps named exports in a module-like namespace |
| `lib/carton/export_methods.rb` | Shared `[]`, `fetch`, `fetch_values`, `values_at`, `key?`, and destructuring support |

## Import flow

1. `import` or `import_relative` delegates to `Carton::Runtime.import`.
2. If the target file has already been imported, the cached value is returned. Otherwise a new `Carton::Box` is created for that import.
3. The carton entrypoint (`lib/carton.rb`) is required inside the box so the box has `export`, `import`, and `import_relative`.
4. The target file is resolved either from the caller's base directory or from the caller box's `$LOAD_PATH`.
5. If the target was found by name, Carton seeds only that matching load-path entry into the new box.
6. The target file is required inside the box.
7. If the file called `export_default`, its value is returned directly.
8. If the file called `export`, its Named Exports are wrapped in `Carton::Exports`.
9. If there was no export, the box itself is returned.

Imports are cached process-wide, keyed by the Entrypoint's real path. The Main Box owns one `Carton::ImportCache` and hands it to every Carton Box it builds, so nested imports hit the same cache. The cache also holds the Main Box's loader, so every Carton is built with the Main Box's `Carton::Box` and `Carton::Exports` no matter which Carton imports it first. Ruby objects are shared across Boxes, so the cached values cross Box boundaries unchanged.

A mutex serialises imports across threads; nested imports on the thread that holds it re-enter directly. A file that is still loading raises `circular import` if imported again. Failed loads are not cached. Targets that do not resolve to an absolute path, such as builtin features, load uncached.

## Export model

There are three return shapes:

- Default Export: the exported object itself
- Export Namespace: `Carton::Exports`
- Bare Carton: `Carton::Box`

`export_default` is the explicit Default Export form and preserves any value,
including a Hash, `nil`, or `false`. `export` is the Export Namespace form and
accepts positional Symbols naming top-level methods plus keyword values.
`KernelPatch#export` resolves each Symbol with `method(name)` on the carton's
top-level object, so a missing method raises `NameError` at export time.
Carton records the form as an immutable Export Declaration instead of
inferring it from the value's class.

`Carton::Exports` defines a forwarding singleton method for each exported
method, exposes capitalized value keys as constants, and exposes lowercase
value keys as readers that return the value unchanged, even when it responds
to `call`. Lookups return the `Method` object for method exports. Both
`Carton::Exports` and `Carton::Box` share the same small fetch/deconstruction
API through `ExportMethods`.

Bare Carton lookup records the constants and top-level helpers introduced by
the Entrypoint. Helper reads return the recorded `Method` object without
invoking it, matching method exports. Runtime constants present before the
Entrypoint loads are not part of the Bare Carton's Public Surface.

Each adapter owns full deconstruction: an Export Namespace enumerates every
Named Export, while a Bare Carton enumerates its discovered Public Surface.
Neither invokes exported or discovered methods.

## Load path model

Ruby 4.0.7 creates Root, Main, and optional user Boxes from an immutable internal Master Box, not from the current caller Box. `require` resolves against the loading Box's local `$LOAD_PATH` / `$LOADED_FEATURES`.

Carton therefore does not copy the caller's whole load path forward. It resolves the feature name in the caller Box first, then carries only the matching load-path entry into the new Box if the imported feature needs that path for its own nested `require` calls.

This is why the examples add sibling `lib/` directories to `$LOAD_PATH` explicitly before using `import 'name'`.

## Bundler model

Bundler setup is explicit inside the Carton entry file:

```ruby
Carton.with_bundle { require 'bundler/setup' }
```

The same line works in the top-level app and inside a Carton. Carton patches
nothing in RubyGems or Bundler; `with_bundle` only scopes `BUNDLE_GEMFILE` and
`BUNDLE_LOCKFILE`.

Ruby 4.0.7 with Bundler 4.0.23 validation:

- per-Carton Bundler setup, Imported Carton bundles, and app-bundle path gems work,
- Main Box activation and load-path state stay unchanged across those imports,
- fresh Boxes start with no gem load paths, even under `bundle exec`,
- `RUBY_BOX=1 bundle exec` evaluates gemspecs and starts the app.

The problem is not that Bundler has special C code mutating every box at once. Bundler and RubyGems do their activation work in Ruby:

- `Bundler::SharedHelpers#find_gemfile` reads `ENV['BUNDLE_GEMFILE']`
- `Bundler::SharedHelpers#default_lockfile` reads `ENV['BUNDLE_LOCKFILE']`
- `Bundler::Runtime#setup` calls `clean_load_path`, `replace_entrypoints`, `mark_loaded`, and `Gem.add_to_load_path`
- RubyGems activation checks and writes `Gem.loaded_specs`

Each Box has its own `$LOAD_PATH` and RubyGems registries, so that work stays
Box-local. Only the `ENV` reads are process-global, which is what
`with_bundle` scopes.

See [how-gems-work.md](internals/how-gems-work.md) and [how-boxes-work.md](internals/how-boxes-work.md) for the deeper runtime model, plus [rubygems-upstream.md](internals/rubygems-upstream.md) and [ruby-upstream.md](internals/ruby-upstream.md) for the minimal upstream work.
