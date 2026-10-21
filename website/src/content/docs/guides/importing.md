---
title: Importing
description: Import Cartons by relative path, by name from the load path, or by absolute path, and plan around Shared Imports.
sidebar:
  order: 3
---

An import loads a Carton into its own Box and returns its export. Only an import crosses a Carton boundary: code loaded with plain `require` stays inside the current Carton.

## `import_relative`

`import_relative path` resolves relative to the calling file, like `require_relative`. A missing file raises `LoadError` naming the files it tried; it never falls back to a same-named feature on `$LOAD_PATH`.

```ruby
Billing = import_relative 'billing'               # billing.rb
Billing = import_relative '../components/billing' # components/billing/lib/billing.rb
```

A path that names a [Gem-shaped Directory](/guides/cartons/#gem-shaped-directories) imports its `lib/<name>.rb` Entrypoint and puts its `lib/` on the Carton's load path. A file of the same name wins over the directory.

## `import`

`import path` takes an absolute path, or searches the current Box's `$LOAD_PATH` like `require`. It never checks the current directory. A missing path or name raises `LoadError`; when the name matches a file beside the calling file, the message suggests `import_relative` instead.

```ruby
Billing = import 'billing'                     # a gem or path gem in the bundle
Widget = import '/absolute/path/to/widget.rb'
```

Gems and path gems in your bundle are already on `$LOAD_PATH`. Import other Cartons by path, or add their `lib/` directories to `$LOAD_PATH` first.

## Shared Imports

Each Carton loads once per process. Later imports of the same file return the same value, whether they come from the app or another Carton, and whether they use `import`, `import_relative`, or an absolute path. Cartons that import the same Carton therefore share its classes, so `is_a?` checks work across them.

```ruby
Money = import 'money'
Money.equal?(import('money')) # => true
```

This is an architectural choice to plan around, not a cache to forget:

- A Carton's module state lasts the whole process, including from one test to the next.
- The First Importer of a shared Gem Carton fixes its gem versions. An Importer whose bundle locks a different version of one of its gems raises `Carton::ImportError`; see [Gem Cartons](/guides/bundler/#gem-cartons). To give two Importers different versions, give each its own copy: a Carton at another path is another Carton.

A failed load is not cached, so a later import tries again. A Carton that imports itself, directly or through other Cartons, raises `Carton::ImportError` (`circular import`).

## Threads

Imports are thread-safe. Threads importing the same Carton share one load, and an Entrypoint can start threads that import other Cartons, as it could with `require`. A thread that imports a Carton its own Importer is still loading waits for it, as `require` would, so do not join such a thread from that Carton's Entrypoint.

## Rakefiles

Rake defines its own `import` on the Rakefile's top-level object, which shadows Carton's. Use `import_relative` in a Rakefile, or call `import` from inside a class or method.
