---
title: carton
description: Reference for the carton command from the carton-tools gem, its commands, PATH arguments, and exit statuses.
sidebar:
  label: Overview
  order: 0
---

The `carton` command comes from the [`carton-tools`](https://rubygems.org/gems/carton-tools) gem, released with `carton` at the same version. It reads code with Prism and never runs it, so it needs no `RUBY_BOX=1`.

```sh
gem install carton-tools   # or add it to your Gemfile's development group
```

## Synopsis

```text
Usage: carton COMMAND [options] PATH...

Commands:
  check  Report import and export problems without running code
  rbs    Write RBS for what each import returns
  graph  Print the import graph as Mermaid or DOT
  why    Show the imports that lead from one file to a Carton

Options:
  -h, --help     Show this help
  -v, --version  Show the version

PATH is a Ruby file or a directory of them, such as main.rb or app.
Imports are followed into every Carton they reach.
Run carton help COMMAND for a command's options.
```

| Command | Summary |
| --- | --- |
| <span id="carton-check"></span>[`carton check`](/reference/cli/check/) | Report import and export problems without running code |
| <span id="carton-rbs"></span>[`carton rbs`](/reference/cli/rbs/) | Write RBS for what each import returns |
| [`carton graph`](/reference/cli/graph/) | Print the import graph as Mermaid or DOT |
| [`carton why`](/reference/cli/why/) | Show the imports that lead from one file to a Carton |

<span id="json-reports"></span>`carton check --format json` reports problems as JSON; see [JSON output](/reference/cli/check/#json-output). `carton --help` prints the synopsis, `carton help COMMAND` or `carton COMMAND --help` prints a command's usage, and `carton --version` prints the version. Help and version go to stdout with exit status 0. A command with no `PATH` prints its usage to stderr with exit status 2.

## Paths and named imports

`PATH` is a Ruby file or a directory of them, such as `main.rb` or `app`. Imports are followed into every Carton they reach. A directory is scanned for `.rb` files, skipping `vendor/bundle` and any `--exclude GLOB`; one with no Ruby files left is a usage error. Named imports resolve against `-I` directories, then the command's own `$LOAD_PATH`, so run it under `bundle exec` in a bundled app to see the bundle's gems.

## Exit status

| Status | Meaning |
| --- | --- |
| 0 | Success |
| 1 | `carton check` found errors, or warnings with `--strict`; `carton rbs --check` found the file missing or stale; or `carton why` found no chain of imports |
| 2 | A usage error, such as an unknown command or option or no `PATH`, or a file that cannot be read or written; the message goes to stderr |
