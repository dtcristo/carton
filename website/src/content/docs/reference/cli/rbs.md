---
title: carton rbs
description: Reference for carton rbs, which writes RBS for what each import returns.
sidebar:
  order: 2
---

Writes RBS for what each import returns, so Steep or another type checker can type the values imports bind. See [Types and checks](/guides/types-and-checks/#rbs-for-imports) for how to use it.

## Synopsis

```text
Usage: carton rbs [options] PATH...
    -I, --include DIR                Add DIR to the load path for named imports
    -o, --output FILE                Where to write the RBS (default sig/generated/carton.rbs, - for stdout)
```

## Options

| Option | Effect |
| --- | --- |
| `-I`, `--include DIR` | Add `DIR` to the load path for named imports. Repeatable. |
| `-o`, `--output FILE` | Where to write the RBS: `sig/generated/carton.rbs` by default, or `-` for stdout |

## Output

The file types what each import returns:

- An exported constant, such as `export Billing`, as `singleton(::Billing)`. The Carton declares `Billing` in its own RBS, as a gem would.
- A keyword export as a record, such as `{ version: ::String }`.
- An export whose type cannot be inferred statically as `untyped`.
- Each literal import path as a `Kernel#import` or `Kernel#import_relative` overload, so a local variable bound to an import is typed too. An `import_relative` path that means different Cartons in different files gets none.
- Each constant bound to an import, such as `Tools = import 'tools'`, unless the Carton's own RBS already declares that name.

Writing a file prints `Wrote FILE` and creates its directory as needed.

## Exit status

0 on success and 2 for a usage error.
