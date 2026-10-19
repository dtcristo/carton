---
title: import, import_relative, export
description: Reference for the three methods Carton adds to Kernel.
sidebar:
  order: 1
  label: Kernel methods
---

`require 'carton'` adds three private methods to `Kernel`, so they are callable from any file, in any Box. Signatures follow Carton's own RBS in [`sig/carton.rbs`](https://github.com/dtcristo/carton/blob/main/sig/carton.rbs).

## `import`

```ruby
def import: (String path) -> untyped
```

Imports the Carton at `path` and returns its Export, or a [`Carton::Namespace`](/reference/namespace/) for a Bare Carton.

- `path` is an absolute path, or a name searched on the current Box's `$LOAD_PATH` like `require`. The current directory is never checked.
- A gem-shaped directory, `billing/lib/billing.rb`, resolves to its `lib/` Entrypoint.
- The first import of a Carton loads it in a new Carton Box. Later imports of the same Entrypoint, by any path, return the same value.

Raises:

- `LoadError` when nothing matches `path`.
- [`Carton::ImportError`](/reference/errors/) when Boxes are disabled, `path` is in a Carton's Interior, the import is circular, or a shared Gem Carton was built against other gem versions.

```ruby
Billing = import 'billing'
```

## `import_relative`

```ruby
def import_relative: (String path) -> untyped
```

Like `import`, but resolves `path` relative to the calling file, like `require_relative`. It never falls back to `$LOAD_PATH`.

```ruby
Billing = import_relative '../components/billing'
```

## `export`

```ruby
def export: [T] (T value) -> T
```

Declares the Carton's Export and returns `value`. Only a call in the imported Entrypoint declares anything; in any other file, `export` checks its argument, returns it, and does nothing else.

- Takes exactly one value. Keywords export a plain Hash: `export version: '1.0'`.
- Raises [`Carton::ExportError`](/reference/errors/) on a second call in one Entrypoint, or for a Symbol.
- Raises `ArgumentError` without exactly one value.

```ruby
export Billing
```
