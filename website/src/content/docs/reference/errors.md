---
title: Errors
description: Every error Carton raises, and when.
sidebar:
  order: 4
---

Carton's own errors subclass `Carton::Error`, a `StandardError`. Every Box shares these classes, so `rescue Carton::Error` works in the app and inside any Carton.

| Error | Raised when |
| --- | --- |
| `Carton::ImportError` | Boxes are disabled (run with `RUBY_BOX=1`), the target is a file inside a Carton, a Carton imports itself, or a shared Gem Carton was built against other gem versions |
| `Carton::ExportError` | `export` is called twice in one Entrypoint or given a Symbol, or a Bare Carton Helper would hide a `Carton::Namespace` method |
| `Carton::GemfileNotFound` | `Carton.setup_bundle` finds no Gemfile |

Otherwise Carton raises what Ruby would: `LoadError` for a missing import target, and `ArgumentError` for `export` without exactly one value.
