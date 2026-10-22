---
title: carton graph
description: Reference for carton graph, which prints the import graph of an app's Cartons as Mermaid or DOT.
sidebar:
  order: 3
---

Prints the import graph without running code: each Carton an app reaches, and the imports between them.

## Synopsis

```text
Usage: carton graph [options] PATH...
    -I, --include DIR                Add DIR to the load path for named imports
        --exclude GLOB               Skip matching files in directory PATHs (and vendor/bundle)
        --format FORMAT              mermaid (default) or dot
    -h, --help                       Show this help
    -v, --version                    Show the version
```

## Options

| Option | Effect |
| --- | --- |
| `-I`, `--include DIR` | Add `DIR` to the load path for named imports. Repeatable. |
| `--exclude GLOB` | Skip files in a directory `PATH` whose path relative to it, or a parent directory's, matches `GLOB`. Repeatable. `**/vendor/bundle` is always skipped |
| `--format FORMAT` | `mermaid` (default), which GitHub and many Markdown renderers draw, or `dot` for Graphviz |
| `-h`, `--help` | Print this usage to stdout and exit 0 |
| `-v`, `--version` | Print the version to stdout and exit 0 |

## Output

Each node is a Carton, named by its Entrypoint's path relative to the working directory, plus `Main` for the app's own files, which run in Main. Each edge is one or more imports from a node's files to a Carton. A dashed edge is lazy: every import behind it runs inside a method or block, so it may run after both Cartons load.

```text
$ carton graph main.rb
flowchart LR
  n0(["Main"])
  n1["billing.rb"]
  n2["report.rb"]
  n0 --> n1
  n1 -.-> n2
```

`carton graph --format dot main.rb | dot -Tsvg > imports.svg` draws it with Graphviz. Imports whose path is not a literal cannot be followed, so they add no edge.

## Exit status

0 on success and 2 for a usage error or a file that cannot be read.
