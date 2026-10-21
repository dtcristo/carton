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

It reads code with Prism and never runs it, so it needs no `RUBY_BOX=1`. Give it the app's files or directories; it follows each import into the Cartons it reaches. Named imports resolve against `-I DIR` and then the command's own `$LOAD_PATH`, so run it under `bundle exec` in a bundled app.

## RBS for imports

`carton rbs main.rb` writes `sig/generated/carton.rbs` (`-o FILE` to change it, `-o -` for stdout), which tells a type checker such as [Steep](https://github.com/soutaro/steep) what each import returns:

- An exported constant, such as `export Billing`, types as `singleton(::Billing)`. The Carton declares `Billing` in its own RBS, as a gem would; Steep reports a missing declaration as an unknown type.
- A keyword export, such as `export version: '1.0'`, types as a record, `{ version: ::String }`.
- A Bare Carton gets a module, such as `Carton::Namespace::Util`, with a singleton method per Helper and a constant per constant. A Helper's type comes from an [rbs-inline](https://github.com/soutaro/rbs-inline) `#:` annotation on the line above it, and a constant's from a `#:` annotation after it or a literal value; otherwise they are `untyped`.
- `Billing = import 'billing'` needs nothing more, and a local variable, `billing = import 'billing'`, types through a `Kernel#import` overload on the literal path.

Load Carton's own signatures and the generated file in the Steepfile, and regenerate the file whenever an import or export changes:

```ruby title="Steepfile"
target :app do
  signature 'sig'
  library 'carton'
  check 'main.rb'
end
```

RBS has one global namespace, so the app's target should check the app's own files. A path such as `import_relative 'tools'` that means different Cartons in different files gets no overload.

## Static checks

`carton check main.rb` prints each problem as `file:line: level: message` and exits non-zero on any error, so it can run in CI. Errors are certain to fail or misbehave when the code runs; warnings are things a dynamic program could still get right. `--strict` fails on warnings too.

It reports, among others:

- an import of a missing path, or of a file inside a Carton
- an import cycle
- a `require` that reaches into another Carton and would load a second copy
- a private constant of an exported module used from outside
- a gem a Gem Carton uses without declaring it in its gemspec
- an unused import binding, excluding constants exposed on a Carton's Public Surface
- a class/module definition opening a directly imported shared class or module

It follows a name bound to an import, `Info = import 'info'` or `info = import 'info'`, to its uses: method calls, constant paths, lookups, and hash patterns. A constant binding is followed in every file of the same Box, a local only in its own file and only when nothing reassigns it.

The [CLI reference](/reference/cli/check/) lists every check.

Use `carton check --format json main.rb` for a machine-readable report of problems and counts. The default text output and exit statuses stay the same. Static checks cannot see every reflective or generated use of an import, and reopening warnings do not guard runtime mutations. Carton does not infer unused members of an exported module or Hash.

## Dynamic imports

An import whose path is computed at runtime, as in plugin discovery, cannot be followed. Mark it with `# carton:dynamic`, on its line or the line above, to say so and silence its warning:

```ruby
Dir.glob('plugins/*/').each do |dir|
  import_relative dir # carton:dynamic
end
```
