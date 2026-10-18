# Usage

Carton splits an app into gem-sized or domain-sized units called Cartons.
Each Carton runs in its own `Ruby::Box`, so its constants, gems, and monkey
patches stay inside, and only what it exports crosses the boundary.
[CONTEXT.md](../CONTEXT.md) has the glossary.

## Requirements

- Ruby 4.0.7+, run with `RUBY_BOX=1` (e.g. `RUBY_BOX=1 ruby main.rb`)
- Bundler 4.0.23+, if you use Bundler
- `require 'carton'` before calling `import`, `import_relative`, `export`, or
  `export_default`

## What a Carton is

A Carton is an Entrypoint file plus the directory named after it, the same
shape as a gem's `lib/` and a Zeitwerk explicit namespace:

```
lib/billing.rb                # the Entrypoint
lib/billing/invoice.rb        # inside the billing Carton
lib/billing/models/charge.rb  # inside too: models/ has no models.rb
```

- The Entrypoint loads the Carton's other files with `require`,
  `require_relative`, or a Zeitwerk loader, all inside the Carton's one Box.
- Only the Entrypoint can be imported. Importing a file inside a Carton raises
  `Carton::ImportError` naming the import to use, because loading it on its
  own would create a second copy of the Carton's classes.
- Directories without their own `.rb` file, like Zeitwerk implicit
  namespaces, belong to the Carton above them, so the outermost Entrypoint
  wins.
- A file with no directory beside it is a Carton of one file.
- Cartons can nest in another Carton's tree, as long as they sit outside its
  namespace directory. In `billing/cartons/tax/lib/tax.rb`, `tax` is its own
  Carton, which `billing.rb` can `import_relative '../cartons/tax'`. Anything
  under `billing/lib/billing/` belongs to `billing`, so put nested Cartons
  beside that directory, not in it.
- No gemspec, Gemfile, or manifest is required. A Carton may be a gem, a path
  gem, a gem-shaped directory, or a plain file.

### Zeitwerk

A Carton's Entrypoint can run its own Zeitwerk loader, such as
`Zeitwerk::Loader.for_gem`, in its own Box with its own copy of Zeitwerk.

- Constants left to autoload load in the Carton's Box, even when an importer
  references them first, and go through the Carton's Zeitwerk, so `on_load`
  callbacks and reloading work. Eager load at boot in production, as usual.
- If the app's own loader manages a directory that contains a Carton,
  `ignore` the Carton's Entrypoint and directory there. Otherwise the app's
  loader can load the Carton's files in the Main Box.
- Reloading a Carton defines new classes inside it, but importers keep
  whatever classes and objects they already hold.

[examples/zeitwerk](../examples/zeitwerk/README.md) shows each case.

## Exporting

### Named Exports

`export` adds names to the Carton's Export Namespace. Call it as often as you
like; each name may be exported once.

```ruby
# pricing.rb
class Money
end
export :Money                     # a capitalized Symbol names a constant

export def add(a, b) = a + b      # `def` returns :add, like `private def`

export PI: 3.14159, version: '1.0.0'
```

- A capitalized Symbol exports the top-level constant of that name; any other
  Symbol exports the top-level method. Both are looked up when `export` runs,
  so export after defining, as with `private` or `private_constant`.
- Keywords export plain values. Capitalized keys become constants and
  lowercase keys become readers. Values are never invoked:
  `export handler: -> {}` makes `handler` return the lambda itself.
- A missing method or constant raises `NameError`, and a repeated name raises
  `Carton::ExportError`, at the `export` call.
- A lowercase name becomes a method on the namespace, so it cannot be a name
  every `Carton::Exports` already has, such as `fetch`, `keys`, or `name`:
  that raises `Carton::ExportError` instead of hiding the built-in method.
  Rename it, or put it inside a Default Export. Capitalized names become
  constants and never collide.

Importing returns a `Carton::Exports` namespace:

```ruby
Pricing = import_relative 'pricing'

Pricing::Money.new
Pricing.add(2, 3)
Pricing::PI
Pricing[:add] # => #<Method: ...add(a, b)>
```

`Pricing.add(...)` forwards arguments, keywords, and blocks. `[]`, `fetch`,
`fetch_values`, `values_at`, `key?`, and destructuring return the `Method`
object without calling it.

### Default Export

Use `export_default` when a file represents one main thing, typically a class
or a root namespace module. Importing the file returns that value itself:

```ruby
# user.rb
class User
  def initialize(name) = @name = name
end

export_default User
```

```ruby
User = import_relative 'user'
User.new('Alice')
```

- The value may be anything, including a Hash, `nil`, or `false`.
- Call it once per file, and never together with `export`; both raise
  `Carton::ExportError`. Put
  other names inside the default value instead, e.g. `User::VERSION`.
- Bind it to its own name (`User = import 'user'`). Rename only to resolve a
  clash between Cartons: `Module#name`, `inspect`, and backtraces keep the
  original name.

### A gem's root module

Make the root module the Default Export and hide internals with Ruby's own
`private_constant`, which holds across Boxes:

```ruby
# lib/pricing.rb
module Pricing
  class Calculator
  end

  module Internal
  end
  private_constant :Internal
end

export_default Pricing
```

```ruby
Pricing = import 'pricing'
Pricing::Calculator # public
Pricing::Internal   # NameError: private constant Pricing::Internal referenced
```

To publish a facade instead, export chosen inner constants by keyword:
`export Calculator: Pricing::Calculator`. Importers then see only those, as
`import('pricing')::Calculator`.

### Exports under plain `require`

Only the imported Entrypoint declares exports. In any other file, including
one loaded with plain `require` by an app or by another Carton, `export` and
`export_default` check their arguments and do nothing. A gem can add
`export_default MyGem` and keep working for apps that just `require 'my_gem'`,
as long as `require 'carton'` comes first so the methods exist.

## Importing

### `import_relative`

`import_relative path` resolves relative to the calling file, like
`require_relative`. A missing file raises `LoadError` naming the files it
tried; it never falls back to a same-named feature on `$LOAD_PATH`.

```ruby
Billing = import_relative 'billing'                  # billing.rb
Billing = import_relative '../components/billing'    # components/billing/lib/billing.rb
```

A path that names a gem-shaped directory, `billing/lib/billing.rb`, imports
that Entrypoint and puts its `lib/` on the Carton's load path, so the Carton
can `require 'billing/invoice'` as a gem would. A file of the same name wins
over the directory.

### `import`

`import path` takes an absolute path, or searches the current Box's
`$LOAD_PATH` like `require`. It never checks the current directory. A missing
path or name raises `LoadError`; when the name matches a file beside the
caller, the message suggests `import_relative` instead.

```ruby
Billing = import 'billing'   # a gem or path gem in the bundle
Widget = import '/absolute/path/to/widget.rb'
```

Gems and path gems in your bundle are already on `$LOAD_PATH`. Import other
Cartons by path, or add their `lib/` directories to `$LOAD_PATH` first.

### Shared imports

Each Carton loads once per process. Later imports of the same file return the
same value, whether they come from the app or another Carton, and whether
they use `import`, `import_relative`, or an absolute path. Cartons that import
the same Carton therefore share its classes, so `is_a?` checks work across
them.

```ruby
Money = import 'money'
Money.equal?(import('money')) # => true
```

A failed load is not cached, so a later import tries again. A Carton that
imports itself, directly or through other Cartons, raises
`Carton::ImportError` (`circular import`).

### Rakefiles

Rake defines its own `import` on the Rakefile's top-level object, which
shadows Carton's. Use `import_relative` in a Rakefile, or call `import` from
inside a class or method.

## Reading exports

Use namespace access, `[]`, or `fetch` for single values, and `fetch_values`
for several:

```ruby
MathTools = import 'math'
MathTools::PI
MathTools[:PI]
MathTools.fetch(:PI)
pi, version = MathTools.fetch_values(:PI, :version)
```

Export Namespaces and Bare Cartons also support pattern matching:

```ruby
import('math') => { add:, version: }
add.(2, 3)

import('math') => { add: sum }        # rename while destructuring
import('math') => { version:, **rest }
rest.keys # => [:add, :PI]
```

A hash-rest pattern collects every Named Export, or every member of a Bare
Carton's Public Surface.

To explore a namespace, `inspect` lists its names, `keys` returns them as
Symbols in export order, and `to_h` returns every export by name:

```ruby
MathTools          # => #<Carton::Exports add, PI, version>
MathTools.keys     # => [:add, :PI, :version]
MathTools.to_h     # => {add: #<Method: ...add(a, b)>, PI: 3.14159, version: "1.0.0"}
```

## Bare Cartons

A file that never calls `export` or `export_default` is a Bare Carton.
Importing it returns a `Carton::Exports` of the constants and top-level helper
methods the file defines, as if it had exported them all. Its Box stays
private, so an importer cannot `eval` or `require` inside it.

```ruby
Toolbox = import 'some_script'

Toolbox::SomeConstant
Toolbox.helper
Toolbox.fetch(:helper).call
```

- Only constants and helpers the Entrypoint introduces count, not constants
  the runtime already defined.
- Constants are read when the import finishes, so an autoloaded top-level
  constant loads then rather than on first use.
- Keys are names, not Ruby expressions. Helper lookups return the `Method`
  object, so `[]`, `fetch`, `key?`, and destructuring never call a helper.

## Sharing classes across Cartons

Boxes isolate monkey patches to builtin classes: patching `String` in one
Carton does not change `String` anywhere else. Classes a Carton defines are
different. An exported class is one object with one definition, shared by
every importer, as in ordinary Ruby. Reopening it from another Carton,
including `class Customer` in a Box where `Customer` names the imported class,
changes it for every Carton.

Box is not a security boundary, so this cannot be prevented outright. These
habits avoid it by accident:

- **Subclass instead of reopening.** Give each Carton its own base classes
  rather than binding a shared one to a bare name:

  ```ruby
  # customers/lib/customers.rb
  class ApplicationRecord < Framework::ApplicationRecord # this Carton's own class
    self.abstract_class = true
  end
  ```

  Changes to a subclass never reach its parent.
- **Refine to extend another Carton's class.** A refinement applies only to
  files that activate it with `using`, so the owning Carton never sees it.
- **Freeze plain-Ruby exports.** `export_default Pricing.freeze` makes any
  reopen raise `FrozenError` while still allowing subclasses. Do not freeze
  Active Record models or their base classes: Rails writes class-level state
  at runtime, so even `create!` raises once a model's class is frozen.

[how-boxes-work.md](internals/how-boxes-work.md#which-classes-get-per-box-copies-ruby-407)
explains why only builtins get per-Box copies.

## Testing Cartons

A Carton has two kinds of test. An integration test imports the Carton and
sees only its Public Surface. A unit test loads the Carton's files with plain
`require` and can reach its internals.

### Integration tests

Tests run in the Main Box, so a test imports a Carton the same way an app
does. Run them with `RUBY_BOX=1`.

```ruby
require 'minitest/autorun'
require 'carton'

class MathTest < Minitest::Test
  def setup
    @math = import_relative '../lib/math'
  end

  def test_add
    assert_equal 5, @math.add(2, 3)
  end
end
```

- Imports are shared across the process, so a Carton's state persists from
  one test to the next. Keep Cartons stateless, or reset their state through
  their Public Surface.
- Files inside a Carton cannot be imported on their own, and private
  constants stay private across the boundary.

### Unit tests

A Carton's files are ordinary Ruby. Outside an Import, `export` and
`export_default` declare nothing, so `require` loads an Entrypoint into the
test's own Box like any other file. A unit test can then test code the Carton
keeps private, and needs no `RUBY_BOX=1`:

```ruby
require 'carton' # defines export_default, which does nothing here
require 'minitest/autorun'
require 'pricing' # plain require: no Import, no boundary

class PricingTest < Minitest::Test
  # Pricing::Rounding raises NameError; const_get still returns it.
  Rounding = Pricing.const_get(:Rounding)

  def test_cents
    assert_equal BigDecimal('1.01'), Rounding.cents(BigDecimal('1.005'))
  end
end
```

- Keep unit and integration tests in separate files, and run each file in
  its own process. A plain `require` loads a second copy of the Carton
  beside the imported one.
- Private code can stay private instead of moving into a Carton of its own.
  A test names it once with `const_get`, or `send` for a private method, so
  each reach into internals is easy to find.

[examples/monorepo/test](../examples/monorepo/test) has both kinds, run
under the monorepo's bundle.

## Bundler

Carton works with or without Bundler. Each Box has its own RubyGems state, so
a Carton's gems never leak into its importer.

### A Carton's own bundle

A Carton that needs its own gems sets up its bundle in its Entrypoint. Other
Cartons need no setup.

```ruby
# cartons/math_helper/lib/math_helper.rb
Carton.setup_bundle

require 'bigdecimal' # this Carton's locked version

export version: BigDecimal::VERSION
```

`Carton.setup_bundle` works like `Bundler.setup`, and the top-level app uses
the same line:

- Pass groups to set up only those, e.g. `Carton.setup_bundle(:default, :test)`.
- It searches upward from the calling file for `gems.rb` or `Gemfile`. Pass
  `gemfile:`, relative to the calling file, to choose one.
- It raises `Carton::GemfileNotFound` when there is no Gemfile, and Bundler
  errors raise instead of exiting.

`RUBY_BOX=1 bundle exec ruby main.rb` also works, including when the Gemfile
evaluates a gemspec.

### `ENV`

`ENV` is shared by the whole process. Bundler reads its Gemfile from
`BUNDLE_GEMFILE` and exports variables such as `RUBYOPT` for subprocesses, so
`setup_bundle` points `BUNDLE_GEMFILE` at the Carton's Gemfile and restores
all of `ENV` when setup finishes. Bundler remembers the Gemfile it chose, so
a later `Bundler.require` in the same Carton still uses it.

- While `setup_bundle` runs, other threads can see the Carton's
  `BUNDLE_GEMFILE` and Bundler's exported variables. Call it while booting,
  before starting threads that read `ENV`.
- Subprocesses never inherit a Carton's bundle, including ones the Carton
  starts. Wrap a subprocess that needs it in `bundle exec`, or pass it
  `BUNDLE_GEMFILE`.

### Gem Cartons

Importing a file from a gem the importer has activated, such as a path gem in
the app's Gemfile, activates that gem and its runtime dependencies in the
Carton's Box at the importer's versions. The gem needs no Gemfile of its own:

```ruby
# Gemfile: gem 'bigdecimal', '3.3.1'; gem 'pricing', path: 'pricing'
Carton.setup_bundle
Pricing = import 'pricing' # pricing's `require 'bigdecimal'` gets 3.3.1
```

- A gem Carton loads once per process, so its first importer fixes its gem
  versions: its dependency closure, plus any locked gem it has loaded
  without declaring, including one required lazily after its import. A
  later importer that activates or locks a different version of one of
  those raises `Carton::ImportError` naming the gem and both versions,
  instead of sharing a Carton built against other versions. A gem the
  Carton first loads after that later import cannot be checked.
- Default gems in the closure keep the importer's activated version too, so
  a newer installed version does not replace it inside the Carton.
- If the importer ran Bundler setup (`Carton.setup_bundle`, `bundler/setup`,
  or `bundle exec`), the gem Carton's Box is restricted to that bundle, as
  `Bundler.setup` restricts the Main Box. Every locked gem loads at its locked
  version, even one the gemspec forgot to declare, and a gem outside the
  lockfile raises `LoadError`.
- Without Bundler, only declared dependencies the importer activated are
  shared. Anything else falls back to RubyGems picking the newest installed
  version inside the Box.
- If the gem Carton also calls `setup_bundle`, its Gemfile must agree with
  the importer's versions, or Bundler raises `Gem::LoadError`.

Because a bundled importer exposes its whole lockfile, a gem Carton can load a
gem it never declared and still work, until it is installed somewhere without
that gem. `carton check` reports each undeclared gem, so the gemspec stays an
accurate manifest; run it under `bundle exec` so it sees the bundle's gems.
Default gems and Carton itself need no declaration.

### Monorepos

To split an app into packages, make each package a path gem in one Gemfile
and import it by gem name. Each gemspec lists the package's dependencies, and
the app's lockfile pins every version. See
[examples/monorepo](../examples/monorepo/README.md).

[how-gems-work.md](internals/how-gems-work.md) has the runtime background, and
[upstream.md](internals/upstream.md) the upstream status.

## Types and checks

The `carton` command reads code with Prism and never runs it, so it needs no
`RUBY_BOX=1`. Give it the app's files or directories; it follows each import
into the Cartons it reaches. Named imports resolve against `-I DIR` and then
the command's own `$LOAD_PATH`, so run it under `bundle exec` in a bundled app.

### RBS

`carton rbs main.rb` writes `sig/generated/carton.rbs` (`-o FILE` to change it,
`-o -` for stdout). It tells a type checker such as
[Steep](https://github.com/soutaro/steep) what each import returns:

- A Default Export of a constant, such as `export_default Billing`, types as
  `singleton(::Billing)`. The Carton declares `Billing` in its own RBS, as a gem
  would; Steep reports a missing declaration as an unknown type.
- Named Exports and Bare Cartons each get a module, such as
  `Carton::Exports::Math`, with a singleton method per exported method and a
  constant per exported value.
- `MathTools = import 'math'` becomes `module MathTools = ::Carton::Exports::Math`,
  so `MathTools.percent` and `MathTools::VERSION` type-check. So does a local
  variable, `math = import 'math'`, through a `Kernel#import` overload on the
  literal path.

An exported method's type comes from an
[rbs-inline](https://github.com/soutaro/rbs-inline) `#:` annotation on the
line above it; without one its parameters are `untyped`. A constant's type
comes from a `#:` annotation after it, or from a literal value:

```ruby
# math.rb
#: (Numeric amount, Numeric rate) -> Float
export def percent(amount, rate) = (amount * rate / 100.0).round(2)

export VERSION: '1.0' # VERSION: ::String
```

Load Carton's own signatures and the generated file in the Steepfile, and
regenerate the file whenever an import or export changes:

```ruby
# Steepfile
target :app do
  signature 'sig'
  library 'carton'
  check 'main.rb'
end
```

RBS has one global namespace, so the app's target should check the app's own
files. A path such as `import_relative 'tools'` that means different Cartons
in different files gets no overload.

### Static checks

`carton check main.rb` prints each problem as `file:line: level: message` and
exits non-zero on any error, so it can run in CI. Errors are certain to fail
or misbehave when the code runs; warnings are things a dynamic program could
still get right. `--strict` fails on warnings too, for a codebase that wants
every import followed.

An import found at runtime, such as plugin discovery, cannot be followed. Mark
it with `# carton:dynamic`, on its line or the line above, to say so and
silence its warning:

```ruby
Dir.glob('plugins/*/').each do |dir|
  import_relative dir # carton:dynamic
end
```

`carton check` follows a name bound to an import, `MathTools = import 'math'`
or `math = import 'math'`, to its uses: method calls, constant paths,
lookups, and hash patterns. A constant binding is followed in every file of
the same Box, a local only in its own file and only when nothing reassigns
it.

| Level | Problem |
| --- | --- |
| error | An import of a missing path, or of a file inside a Carton |
| error | An import cycle, unless an import in it runs lazily (then a warning) |
| error | A `require` or `require_relative` of an imported Carton's file from outside it, which loads a second copy |
| error | `export_default` twice, `export_default` with `export`, or a name exported twice, in calls that can both run (calls in different branches of one `if` or `case` cannot), or a lowercase export (or Bare Carton method) that would hide a `Carton::Exports` method |
| error | A gem Carton importing or requiring a gem its gemspec does not declare |
| error | A Named Export that does not exist, used where it would raise: `MathTools.nope`, `MathTools::NOPE`, `fetch(:nope)`, or a `=>` pattern. `[]`, `key?` and `in` patterns return nil or false instead, and Default Exports and Bare Cartons are not checked |
| error | A private constant of a Default Export, such as `Billing::Tax` when `Billing` calls `private_constant :Tax` |
| error | A syntax error |
| warning | A named import not found on the load path, which a gem activated at runtime may provide |
| warning | An import whose path is not a string literal, unless marked `# carton:dynamic` |
| warning | `export` in a file inside a Carton, where it does nothing |

## Errors

Carton's own errors subclass `Carton::Error`:

| Error | Raised when |
| --- | --- |
| `Carton::ImportError` | Boxes are disabled (run with `RUBY_BOX=1`), the target is a file inside a Carton, a Carton imports itself, or a shared Carton was built against other gem versions |
| `Carton::ExportError` | a name is exported twice, `export_default` is called twice, both forms are used, or a lowercase name would hide a `Carton::Exports` method |
| `Carton::GemfileNotFound` | `setup_bundle` finds no Gemfile |

Otherwise Carton raises what Ruby would: `LoadError` for a missing import
target, `NameError` for a missing exported name, and `ArgumentError` for
invalid `export` arguments. Every Box shares these classes, so
`rescue Carton::Error` works in the app and inside any Carton.

## Examples

The [README](../README.md#docs) lists every example. Run one with
`RUBY_BOX=1 ruby examples/<name>/main.rb`.
