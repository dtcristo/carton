# Design

## Goal

Keep the library small: a thin wrapper around `Ruby::Box` that makes isolated file-to-file imports feel like part of Ruby.

## Main pieces

| File | Role |
| --- | --- |
| `lib/carton.rb` | Entry point and internal wiring |
| `lib/carton/bundler.rb` | `Carton.setup_bundle` plus caller-file bundle discovery |
| `lib/carton/kernel_patch.rb` | Adds global `import`, `import_relative`, `export_default`, and `export` |
| `lib/carton/import_cache.rb` | Process-wide import cache shared by every Box |
| `lib/carton/gem_activation.rb` | Finds the activated gem that owns an Import and activates its dependency closure in the new Box |
| `lib/carton/resolver.rb` | Maps an Import path to a file without evaluating code, given a load path |
| `lib/carton/runtime.rb` | Builds boxes, runs imports, and extracts exports |
| `lib/carton/box.rb` | Box-specific helpers for requiring files, holding and resetting the current Export Declaration, and seeding an imported feature's load path |
| `lib/carton/export_declaration.rb` | Owns absence, uniqueness, kind, snapshotting, and Public Surface conversion for an Export Declaration |
| `lib/carton/exports.rb` | Wraps named exports in a module-like namespace |
| `lib/carton/export_methods.rb` | Shared `[]`, `fetch`, `fetch_values`, `values_at`, `key?`, and destructuring support |

## Import flow

1. `import` or `import_relative` delegates to `Carton::Runtime.import`.
2. `Carton::Resolver` resolves the target: `import_relative` from the calling file's directory, `import` from an absolute path or the caller box's `$LOAD_PATH`. It never checks the current directory and reads no Box state, so static tools can reuse it.
3. If the target file has already been imported, the cached value is returned. Otherwise a new `Carton::Box` is created for that import.
4. The carton entrypoint (`lib/carton.rb`) is required inside the box so the box has `export`, `import`, and `import_relative`.
5. If the target was found by name, Carton seeds only that matching load-path entry into the new box.
6. If an activated gem in the caller owns the target, that gem and its activated runtime dependencies are activated in the new box at the caller's versions, dependencies first.
7. The target file is required inside the box.
8. If the file called `export_default`, its value is returned directly.
9. If the file called `export`, its Named Exports are wrapped in `Carton::Exports`.
10. If there was no export, the box itself is returned.

Imports are cached process-wide, keyed by the Entrypoint's real path. The Main Box owns one `Carton::ImportCache` and hands it to every Carton Box it builds, so nested imports hit the same cache. The cache also holds the Main Box's loader, so every Carton is built with the Main Box's `Carton::Box` and `Carton::Exports` no matter which Carton imports it first. Ruby objects are shared across Boxes, so the cached values cross Box boundaries unchanged.

Each cache entry also records the gem versions activated for it. A later import of the same Entrypoint whose caller activates a different version of one of those gems raises instead of reusing the entry, so one shared Carton never serves two lockfiles.

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

Bundler setup is explicit, one line in the app or in a Carton's Entrypoint:

```ruby
Carton.setup_bundle
```

Carton patches nothing in RubyGems or Bundler. Bundler and RubyGems do their
activation work in Ruby, against `$LOAD_PATH`, `Gem.loaded_specs`, and the
`Gem::Specification` registries, and each Box has its own copy of all three.
Running `Bundler.setup` inside a Carton's Box therefore activates gems only in
that Box.

`ENV` is the exception, because it is process-global. Bundler reads
`BUNDLE_GEMFILE` and `BUNDLE_LOCKFILE` to find the bundle and exports
subprocess variables such as `RUBYOPT`. `setup_bundle` sets the Gemfile from
the calling file, clears the lockfile, and restores all of `ENV` after setup,
so importing a Carton never changes the environment Main's subprocesses see.

See [how-gems-work.md](internals/how-gems-work.md) and
[how-boxes-work.md](internals/how-boxes-work.md) for the runtime model, and
[upstream.md](internals/upstream.md) for upstream status.
