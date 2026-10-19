---
title: Carton::Namespace
description: Reference for the module a Bare Carton's importers receive, and its lookup methods.
sidebar:
  order: 3
---

Importing a [Bare Carton](/guides/bare-cartons/) returns a `Carton::Namespace`: a `Module` holding the constants and Helpers the Entrypoint defined. Constants are constants on it, and each Helper is a singleton method that forwards to the Carton.

```ruby
Toolbox = import 'some_script'
Toolbox::SomeConstant
Toolbox.helper(1)
```

## Lookup methods

Every namespace also has these lookup methods, from `Carton::NamespaceMethods`. A key is a String or Symbol name, never a Ruby expression. Helper lookups return the `Method` object, so they never call a Helper.

| Method | Returns |
| --- | --- |
| `[](key)` | The member, or `nil` |
| `fetch(key)` | The member; raises `KeyError` when missing, or returns the default or block result |
| `fetch_values(*keys)` | An Array of members; raises `KeyError` for a missing one |
| `values_at(*keys)` | An Array of members, `nil` for missing ones |
| `key?(key)`, `has_key?(key)` | Whether the member exists |
| `keys` | Every member name, as Symbols |
| `to_h` | A Hash of every member by Symbol name |
| `deconstruct_keys(keys)` | Members for hash patterns, such as `Toolbox => { helper: }` |

A Helper whose name would hide one of these methods, or a `Module` method such as `name`, raises `Carton::ExportError` when the Carton is imported.
