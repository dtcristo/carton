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
        --exclude GLOB               Skip matching files in directory PATHs (and vendor/bundle)
        --strict                     Fail on warnings too, not only errors
        --format FORMAT              text (default) or json
    -h, --help                       Show this help
    -v, --version                    Show the version
```

## Options

| Option | Effect |
| --- | --- |
| `-I`, `--include DIR` | Add `DIR` to the load path for named imports. Repeatable. |
| `--exclude GLOB` | Skip files in a directory `PATH` whose path relative to it, or a parent directory's, matches `GLOB`, such as `tmp` or `**/fixtures`. Repeatable. `**/vendor/bundle` is always skipped. Files reached by imports are still read |
| `--strict` | Exit 1 on warnings too, not only errors |
| `--format FORMAT` | `text` (default) or `json` |
| `-h`, `--help` | Print this usage to stdout and exit 0 |
| `-v`, `--version` | Print the version to stdout and exit 0 |

## Exit status

0 when there are no errors, 1 when there are errors (or any problem with `--strict`), and 2 for a usage error or a file that cannot be read. JSON output has the same statuses.

## Problems

Text output prints each problem as `file:line:column: level: message [rule]`, then a summary line of files, Cartons, errors, and warnings. Columns count characters from 1. A Carton is named by its Entrypoint's path relative to the working directory, such as `billing.rb`.

Each problem has a stable rule ID:

| Rule | Level | Problem |
| --- | --- | --- |
| `syntax-error` | error | A syntax error |
| `import-error` | error | An import of a missing path, or of a file inside a Carton |
| `import-cycle` | error | An import cycle, unless an import in it runs lazily (then a warning). Each set of Cartons that import each other reports one shortest cycle, preferring one with no lazy import |
| `second-copy` | error | A `require` or `require_relative` of an imported Carton's file from outside it, which loads a Second Copy |
| `missing-export` | error | An imported Entrypoint with no `export` |
| `export-twice` | error | `export` twice in calls that can both run. Calls in different branches of one `if` or `case` cannot |
| `export-symbol` | error | `export` of a Symbol |
| `export-arity` | error | `export` with no value or more than one |
| `undeclared-gem` | error | A Gem Carton importing or requiring a gem its gemspec does not declare |
| `missing-key` | error | A key a keyword or Hash literal export does not have, read with `fetch(:nope)` or a `=>` pattern. `[]`, `key?`, and `in` patterns return `nil` or `false` instead |
| `private-constant` | error | A private constant of an exported module, such as `Billing::Tax` when `Billing` calls `private_constant :Tax` |
| `unfound-import` | warning | A named import not found on the load path, which a gem activated at runtime may provide |
| `dynamic-import` | warning | An import whose path is not a string literal, unless marked `# carton:dynamic` |
| `export-outside-entrypoint` | warning | `export` in a file inside a Carton, where it does nothing |
| `unused-import` | warning | An import bound to a constant or unreassigned local with no observed uses, unless the constant is part of an exported module's Public Surface |
| `reopened-class` | warning | A class/module definition that opens a directly imported value or a constant beneath it, changing a shared class or module |

The missing-export check applies to imported Entrypoints, not hosts or files loaded with plain `require`. Static analysis accepts possible `export` calls, including calls inside module bodies or methods, without proving that they run. A conditional or uncalled export can still leave an import raising `Carton::ExportError`.

Import-use warnings cover the scanned files, not reflection or generated code. An unbound import can run for its side effects and is not unused. Reopening checks follow direct constant bindings, including qualified and absolute paths, but cannot follow aliases or dynamic mutations such as `class_eval` and `define_method`. Subclassing and definitions of local classes do not warn. These checks add no runtime guard, and no check infers unused members of an exported module or Hash.

## JSON output

`carton check --format json main.rb` prints one JSON object with the format `version` (now `1`), `problems`, and the counts `files`, `cartons`, `errors`, and `warnings`. Each problem has `level`, `rule`, `file`, `line`, `column`, and `message`:

```json
{
  "version": 1,
  "problems": [
    {
      "level": "warning",
      "rule": "unused-import",
      "file": "main.rb",
      "line": 1,
      "column": 9,
      "message": "Tools is bound to an import of the tools.rb Carton but never used"
    }
  ],
  "files": 2,
  "cartons": 1,
  "errors": 0,
  "warnings": 1
}
```

`version` changes only when a field is removed or changes meaning; new fields may appear without it changing. Paths inside the working directory are relative to it; paths outside it stay absolute. JSON has the same exit statuses as text output, including `--strict`. Usage errors still go to stderr as text with exit status 2.
