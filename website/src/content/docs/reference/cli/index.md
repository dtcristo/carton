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
  rbs    Write RBS for what each import returns
  check  Report import and export problems without running code

PATH is a Ruby file or a directory of them, such as main.rb or app.
Imports are followed into every Carton they reach.
```

| Command | Summary |
| --- | --- |
| [`carton check`](/reference/cli/check/) | Report import and export problems without running code |
| [`carton rbs`](/reference/cli/rbs/) | Write RBS for what each import returns |

`carton --help` prints the synopsis, and a command with no `PATH` prints its own usage.

## Paths and named imports

`PATH` is a Ruby file or a directory of them, such as `main.rb` or `app`. Imports are followed into every Carton they reach. Named imports resolve against `-I` directories, then the command's own `$LOAD_PATH`, so run it under `bundle exec` in a bundled app to see the bundle's gems.

## Exit status

| Status | Meaning |
| --- | --- |
| 0 | Success |
| 1 | `carton check` found errors, or warnings with `--strict` |
| 2 | A usage error, such as an unknown command or option, a missing file, or no `PATH`; the message goes to stderr |
