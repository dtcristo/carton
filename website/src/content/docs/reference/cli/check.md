---
title: carton check
description: Reference for carton check, which reports import and export problems without running code, as text or JSON.
sidebar:
  order: 1
---

Reports import and export problems without running code. See [Types and checks](/guides/types-and-checks/) for how to use it.

## Synopsis

```text
Usage: carton check [options] PATH...
    -I, --include DIR                Add DIR to the load path for named imports
        --strict                     Fail on warnings too, not only errors
        --format FORMAT              text (default) or json
```

## Options

| Option | Effect |
| --- | --- |
| `-I`, `--include DIR` | Add `DIR` to the load path for named imports. Repeatable. |
| `--strict` | Exit 1 on warnings too, not only errors |
| `--format FORMAT` | `text` (default) or `json` |

## Exit status

0 when there are no errors, 1 when there are errors (or any problem with `--strict`), and 2 for a usage error. JSON output has the same statuses.

## Problems

Text output prints each problem as `file:line: level: message`, then a summary line of files, Cartons, errors, and warnings.

| Level | Problem |
| --- | --- |
| error | An import of a missing path, or of a file inside a Carton |
| error | An import cycle, unless an import in it runs lazily (then a warning) |
| error | A `require` or `require_relative` of an imported Carton's file from outside it, which loads a Second Copy |
| error | An imported Entrypoint with no `export`, `export` twice in calls that can both run (calls in different branches of one `if` or `case` cannot), or `export` of a Symbol |
| error | A Gem Carton importing or requiring a gem its gemspec does not declare |
| error | A key a keyword or Hash literal export does not have, read with `fetch(:nope)` or a `=>` pattern. `[]`, `key?`, and `in` patterns return `nil` or `false` instead |
| error | A private constant of an exported module, such as `Billing::Tax` when `Billing` calls `private_constant :Tax` |
| error | A syntax error |
| warning | A named import not found on the load path, which a gem activated at runtime may provide |
| warning | An import whose path is not a string literal, unless marked `# carton:dynamic` |
| warning | `export` in a file inside a Carton, where it does nothing |
| warning | An import bound to a constant or unreassigned local with no observed uses, unless the constant is part of an exported module's Public Surface |
| warning | A class/module definition that opens a directly imported value or a constant beneath it, changing a shared class or module |

The missing-export check applies to imported Entrypoints, not hosts or files loaded with plain `require`. Static analysis accepts possible `export` calls, including calls inside module bodies or methods, without proving that they run. A conditional or uncalled export can still leave an import raising `Carton::ExportError`.

Import-use warnings cover the scanned files, not reflection or generated code. An unbound import can run for its side effects and is not unused. Reopening checks follow direct constant bindings, including qualified and absolute paths, but cannot follow aliases or dynamic mutations such as `class_eval` and `define_method`. Subclassing and definitions of local classes do not warn. These checks add no runtime guard, and no check infers unused members of an exported module or Hash.

## JSON output

`carton check --format json main.rb` prints one JSON object with `problems` and the counts `files`, `cartons`, `errors`, and `warnings`. Each problem has `level`, `file`, `line`, and `message`:

```json
{
  "problems": [
    {
      "level": "warning",
      "file": "main.rb",
      "line": 1,
      "message": "Tools is bound to an import of the tools Carton but never used"
    }
  ],
  "files": 2,
  "cartons": 1,
  "errors": 0,
  "warnings": 1
}
```

Paths inside the working directory are relative to it; paths outside it stay absolute. JSON has the same exit statuses as text output, including `--strict`. Usage errors still go to stderr as text with exit status 2.
