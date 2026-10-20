---
title: Types and checks
description: Generate RBS for what each import returns, and catch boundary problems before the code runs with carton check.
sidebar:
  order: 8
---

The `carton` command ships in the `carton-tools` gem, released with `carton` at the same version, so apps and gems built on Carton do not install it. Add it where your checks run:

```ruby title="Gemfile"
gem 'carton'
gem 'carton-tools', group: :development
```

It reads code with Prism and never runs it, so it needs no `RUBY_BOX=1`. Give it the app's files or directories; it follows each import into the Cartons it reaches. Run it under `bundle exec` in a bundled app so named imports resolve.

## RBS for imports

`carton rbs main.rb` writes `sig/generated/carton.rbs`, which tells a type checker such as [Steep](https://github.com/soutaro/steep) what each import returns:

- An exported constant, such as `export Billing`, types as `singleton(::Billing)`. The Carton declares `Billing` in its own RBS, as a gem would.
- A keyword export, such as `export version: '1.0'`, types as a record, `{ version: ::String }`.
- A Bare Carton gets a module, such as `Carton::Namespace::Util`, with a singleton method per Helper and a constant per constant. Types come from [rbs-inline](https://github.com/soutaro/rbs-inline) `#:` annotations, or are `untyped`.

Load Carton's own signatures and the generated file in the Steepfile, and regenerate the file whenever an import or export changes:

```ruby title="Steepfile"
target :app do
  signature 'sig'
  library 'carton'
  check 'main.rb'
end
```

## Static checks

`carton check main.rb` prints each problem as `file:line: level: message` and exits non-zero on any error, so it can run in CI. Errors are certain to fail or misbehave when the code runs; warnings are things a dynamic program could still get right. `--strict` fails on warnings too.

It reports, among others:

- an import of a missing path, or of a file inside a Carton
- an import cycle
- a `require` that reaches into another Carton and would load a second copy
- a private constant of an exported module used from outside
- a gem a Gem Carton uses without declaring it in its gemspec

The [CLI reference](/reference/cli/) lists every check.

## Dynamic imports

An import whose path is computed at runtime, as in plugin discovery, cannot be followed. Mark it with `# carton:dynamic`, on its line or the line above, to say so and silence its warning:

```ruby
Dir.glob('plugins/*/').each do |dir|
  import_relative dir # carton:dynamic
end
```
