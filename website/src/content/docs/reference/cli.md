---
title: carton command
description: Reference for carton rbs and carton check, from the carton-tools gem.
sidebar:
  order: 5
---

The `carton` command comes from the `carton-tools` gem. It reads code with Prism and never runs it, so it needs no `RUBY_BOX=1`.

```sh
carton COMMAND [options] PATH...
```

`PATH` is a Ruby file or a directory of them, such as `main.rb` or `app`. Imports are followed into every Carton they reach. Named imports resolve against `-I` directories, then the command's own `$LOAD_PATH`, so run it under `bundle exec` in a bundled app.

| Option | Commands | Effect |
| --- | --- | --- |
| `-I`, `--include DIR` | both | Add `DIR` to the load path for named imports |
| `-o`, `--output FILE` | `rbs` | Where to write the RBS; `-` for stdout |
| `--strict` | `check` | Fail on warnings too, not only errors |
| `--format FORMAT` | `check` | `text` (default) or `json` |

Exit status is 0 on success, 1 when `check` finds errors (or warnings with `--strict`), and 2 for a usage error.

## `carton rbs`

Writes RBS for what each import returns, by default to `sig/generated/carton.rbs`. See [Types and checks](/guides/types-and-checks/#rbs-for-imports).

## `carton check`

Prints each problem as `file:line: level: message`, then a summary line.

| Level | Problem |
| --- | --- |
| error | An import of a missing path, or of a file inside a Carton |
| error | An import cycle, unless an import in it runs lazily (then a warning) |
| error | A `require` or `require_relative` of an imported Carton's file from outside it, which loads a second copy |
| error | `export` twice in calls that can both run (calls in different branches of one `if` or `case` cannot), `export` of a Symbol, or a Bare Carton Helper that would hide a `Carton::Namespace` method |
| error | A Gem Carton importing or requiring a gem its gemspec does not declare |
| error | A key a keyword or Hash literal export does not have, read with `fetch(:nope)` or a `=>` pattern. `[]`, `key?`, and `in` patterns return `nil` or `false` instead |
| error | A private constant of an exported module, such as `Billing::Tax` when `Billing` calls `private_constant :Tax` |
| error | A syntax error |
| warning | A named import not found on the load path, which a gem activated at runtime may provide |
| warning | An import whose path is not a string literal, unless marked `# carton:dynamic` |
| warning | `export` in a file inside a Carton, where it does nothing |
| warning | An import bound to a constant or unreassigned local with no observed uses, unless the constant is part of a Bare Carton's or exported module's Public Surface |
| warning | A class/module definition that opens a directly imported value or a constant beneath it, changing a shared class or module |

Import-use warnings cover the scanned files, not reflection or generated code. An unbound import can run for its side effects and is not unused. Reopening checks follow direct constant bindings, including qualified and absolute paths, but cannot follow aliases or dynamic mutations such as `class_eval` and `define_method`. Subclassing and definitions of local classes do not warn. These checks add no runtime guard, and no check infers unused members of an exported module or Hash.

### JSON reports

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
