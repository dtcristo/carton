---
title: carton why
description: Reference for carton why, which prints the chain of imports that leads from one file to a Carton.
sidebar:
  order: 4
---

Prints the shortest chain of imports from `FROM` to the Carton that holds `TO`, without running code. Use it to find out why a Carton loads.

## Synopsis

```text
Usage: carton why [options] FROM TO
    -I, --include DIR                Add DIR to the load path for named imports
    -h, --help                       Show this help
    -v, --version                    Show the version
```

## Options

| Option | Effect |
| --- | --- |
| `-I`, `--include DIR` | Add `DIR` to the load path for named imports. Repeatable. |
| `-h`, `--help` | Print this usage to stdout and exit 0 |
| `-v`, `--version` | Print the version to stdout and exit 0 |

## Output

`FROM` is a Ruby file, such as `main.rb`; only it and what it imports are read. `TO` is a Carton's Entrypoint or any file in its Interior. Each line is one import, as `file:line:column: call -> Carton`:

```text
$ carton why main.rb report.rb
main.rb:1:11: import_relative 'billing' -> billing.rb
billing.rb:2:14: import_relative 'report' -> report.rb
```

## Exit status

0 when `FROM` reaches `TO`, 1 when it does not, and 2 for a usage error or a file that cannot be read.
