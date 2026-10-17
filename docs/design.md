# Design

## Goal

Keep the library small: a thin layer over `Ruby::Box` that makes isolated
file-to-file imports feel like part of Ruby.

## Main pieces

| File | Role |
| --- | --- |
| `lib/carton.rb` | Entry point; loads the pieces below |
| `lib/carton/error.rb` | `Carton::Error` and its subclasses |
| `lib/carton/kernel_patch.rb` | Private `Kernel#import`, `#import_relative`, `#export`, and `#export_default` |
| `lib/carton/runtime.rb` | Resolves an Import, checks the cache, and builds a Carton Box; validates `export` calls |
| `lib/carton/resolver.rb` | Maps an Import path to a file, given a load path, without evaluating code |
| `lib/carton/import_cache.rb` | Process-wide import cache shared by every Box |
| `lib/carton/box.rb` | The Carton Box: runs one Import from boot to Public Surface and holds its Export Declaration |
| `lib/carton/export_declaration.rb` | One Entrypoint's exports: uniqueness, Default Export versus Export Namespace, and the Public Surface |
| `lib/carton/exports.rb` | `Carton::Exports`, the module-like namespace importers receive |
| `lib/carton/export_methods.rb` | Shared `[]`, `fetch`, `fetch_values`, `values_at`, `key?`, and destructuring |
| `lib/carton/gem_activation.rb` | Gem Carton activation; the only place Carton calls Bundler internals |
| `lib/carton/activate_gems.rb` | Required inside a new Box so activation writes that Box's `$LOAD_PATH` |
| `lib/carton/bundler.rb` | `Carton.setup_bundle` and Gemfile discovery from the calling file |

## Import flow

1. `import` or `import_relative` calls `Carton::Runtime.import`.
2. `Carton::Resolver` resolves the target: `import_relative` from the calling
   file's directory, `import` from an absolute path or the calling Box's
   `$LOAD_PATH`. It never checks the current directory and reads no Box
   state, so static tools can reuse it.
3. If the target is already imported, the cached value is returned. Otherwise
   Carton creates a new `Carton::Box`.
4. Carton requires its own `lib/carton.rb` inside the Box, so the Carton can
   call `import` and `export`, then points that copy's error classes at the
   importer's, so `rescue Carton::Error` matches errors from any Box.
5. If the target was found by name, only the load-path entry that matched is
   added to the new Box.
6. If an activated gem in the caller owns the target, that gem and its
   activated runtime dependencies are activated in the new Box at the
   caller's versions, dependencies first. If the caller ran Bundler setup, the
   Box is first restricted to the caller's locked gems and all of them are
   activated, as `Bundler.setup` does.
7. The target file is required inside the Box.
8. A Default Export is returned as is. Named Exports are wrapped in
   `Carton::Exports`. With no exports, the constants and top-level helpers the
   Entrypoint defined are wrapped instead. The Box itself never leaves Carton.

Imports are cached process-wide, keyed by the Entrypoint's real path. The
Main Box owns one `Carton::ImportCache` and hands it to every Carton Box it
builds, so nested imports hit the same cache. The cache also holds the Main
Box's loader, so every Carton is built with the Main Box's `Carton::Box` and
`Carton::Exports`, whichever Carton imports it first. Ruby objects are shared
across Boxes, so cached values cross Box boundaries unchanged.

Each cache entry records the gem versions activated for it. A later import of
the same Entrypoint whose caller has different versions activated raises
instead of reusing the entry, so one shared Carton never serves two
lockfiles.

A mutex serializes imports across threads; nested imports on the thread that
holds it re-enter directly. Importing a file that is still loading raises
`circular import`. Failed loads are not cached. Targets that do not resolve to
an absolute path, such as builtin features, load uncached.

## Export model

There are three return shapes:

- Default Export: the `export_default` value itself
- Export Namespace: `Carton::Exports` of the Named Exports from every `export`
  call
- Bare Carton: `Carton::Exports` of the discovered Public Surface

`export_default` may be called once and never alongside `export`, so the
author's choice decides the shape and no name becomes unreachable.

`export` takes positional Symbols plus keyword values. A capitalized Symbol
names a top-level constant, read with `Object.const_get(name, false)`; any
other Symbol names a top-level method, captured with `method(name)` on the
Carton's top-level object. Both are looked up at the call, so a missing name
raises `NameError` there. Each call adds to an immutable Export Declaration,
which rejects a name exported twice. `KernelPatch#export` passes the calling
file to `Runtime`, which declares only when that file is the importing Box's
Entrypoint; elsewhere `export` validates its arguments and does nothing.

`Carton::Exports` defines a forwarding singleton method for each exported
method, exposes capitalized value keys as constants, and exposes lowercase
value keys as readers that return the value unchanged, even when it responds
to `call`. Lookups through `ExportMethods` return the `Method` object for
method exports.

A Bare Carton's Public Surface is the constants and top-level helpers its
Entrypoint introduced; constants the runtime defined beforehand are excluded.
Carton reads the constants when the import finishes and builds the same
`Carton::Exports` an Export Namespace uses. Helper lookups return the recorded
`Method` object without calling it.

Full deconstruction enumerates every Named Export, or every member of a Bare
Carton's Public Surface, and never calls a method.

## Load path model

Ruby 4.0.7 creates the Root Box, the Main Box, and every optional Box from its
internal Master Box, not from the calling Box. `require` resolves against the
loading Box's own `$LOAD_PATH` and `$LOADED_FEATURES`.

Carton therefore does not copy the caller's whole load path forward. It
resolves the feature in the calling Box, then adds only the matching
load-path entry to the new Box, so the Carton's own nested `require` calls
work. Gems in the caller's bundle are already on its load path; local
Cartons that are not gems need their `lib/` directories added before
`import 'name'`.

## Bundler model

Bundler setup is explicit, one line in the app or in a Carton's Entrypoint:

```ruby
Carton.setup_bundle
```

Carton patches nothing in RubyGems or Bundler. They do their activation work
in Ruby, against `$LOAD_PATH`, `Gem.loaded_specs`, and the
`Gem::Specification` registries, and each Box has its own copy of all three.
Running `Bundler.setup` inside a Carton's Box therefore activates gems only in
that Box.

`ENV` is the exception, because it is process-global. Bundler reads
`BUNDLE_GEMFILE` and `BUNDLE_LOCKFILE` to find the bundle and exports
subprocess variables such as `RUBYOPT`. `setup_bundle` sets the Gemfile from
the calling file, clears the lockfile, and restores all of `ENV` after setup,
so importing a Carton never changes the environment the Main Box's
subprocesses see.

Gem Cartons need no setup of their own; step 6 of the import flow carries the
caller's activated versions into their Box.

See [how-gems-work.md](internals/how-gems-work.md) and
[how-boxes-work.md](internals/how-boxes-work.md) for the runtime model, and
[upstream.md](internals/upstream.md) for upstream status.
