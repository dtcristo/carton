---
title: Bare Cartons
description: Import a file that never calls export, and read its constants and Helpers through a Carton::Namespace.
sidebar:
  order: 4
---

A file that never calls `export` is a Bare Carton. Importing it returns a [`Carton::Namespace`](/reference/namespace/) of the constants and top-level methods, called Helpers, that the file defines, as if it had exported them all.

Its Box stays private, so an Importer cannot `eval` or `require` inside it. Bare Cartons suit existing code you want to load in a Box without changing it; new Cartons should export deliberately.

```ruby
# main.rb
Toolbox = import 'some_script' # some_script.rb never calls export

Toolbox::SomeConstant
Toolbox.helper
Toolbox[:helper]         # => #<Method: ...helper()>, not called
Toolbox.fetch(:SomeConstant)
Toolbox => { helper:, **rest }
Toolbox                  # => #<Carton::Namespace helper, SomeConstant>
```

- Only constants and Helpers the Entrypoint introduces count, not constants the runtime already defined.
- Constants are read when the import finishes, so an autoloaded top-level constant loads then rather than on first use.
- Lookups by name, such as `[]`, `fetch`, and destructuring, return a Helper's `Method` object, so they never call it.
- A Helper named like a `Carton::Namespace` method, such as `fetch`, `keys`, or `name`, raises `Carton::ExportError` instead of hiding it.
