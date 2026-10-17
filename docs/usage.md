# Usage

An importable Ruby file and everything it loads is a Carton. Each Carton runs
in its own `Ruby::Box`, so its constants, gems, and monkey patches stay inside,
and only what it exports crosses the boundary. [CONTEXT.md](../CONTEXT.md) has
the glossary.

## Requirements

- Ruby 4.0.7+, run with `RUBY_BOX=1` (e.g. `RUBY_BOX=1 ruby main.rb`)
- Bundler 4.0.23+, if you use Bundler
- `require 'carton'` before calling `import`, `import_relative`, `export`, or
  `export_default`

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
`require_relative`. A missing file raises `LoadError`; it never falls back to
a same-named feature on `$LOAD_PATH`.

```ruby
User = import_relative 'user'
```

### `import`

`import path` takes an absolute path, or searches the current Box's
`$LOAD_PATH` like `require`. It never checks the current directory. A missing
path or name raises `LoadError`.

```ruby
MathTools = import 'math_tools'
Widget = import '/absolute/path/to/widget.rb'
```

Gems and path gems in your bundle are already on `$LOAD_PATH`. For local
Cartons that are not gems, add their `lib/` directories first, as
[examples/bundler](../examples/bundler/main.rb) does:

```ruby
Dir.glob(File.join(__dir__, 'cartons/*/lib')).each do |dir|
  $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)
end
```

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
- A test sees only the Public Surface. To test the internals of a Carton that
  exports, move them into a Carton of their own and import that directly.

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
  versions. A later importer with different versions activated raises
  `Carton::ImportError` naming the gem and both versions, instead of sharing a
  Carton built against other versions.
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

### Monorepos

To split an app into packages, make each package a path gem in one Gemfile
and import it by gem name. Each gemspec lists the package's dependencies, and
the app's lockfile pins every version. See
[examples/monorepo](../examples/monorepo/README.md).

[how-gems-work.md](internals/how-gems-work.md) has the runtime background, and
[upstream.md](internals/upstream.md) the upstream status.

## Errors

Carton's own errors subclass `Carton::Error`:

| Error | Raised when |
| --- | --- |
| `Carton::ImportError` | Boxes are disabled (run with `RUBY_BOX=1`), a Carton imports itself, or a shared Carton was built against other gem versions |
| `Carton::ExportError` | a name is exported twice, `export_default` is called twice, or both forms are used |
| `Carton::GemfileNotFound` | `setup_bundle` finds no Gemfile |

Otherwise Carton raises what Ruby would: `LoadError` for a missing import
target, `NameError` for a missing exported name, and `ArgumentError` for
invalid `export` arguments. Every Box shares these classes, so
`rescue Carton::Error` works in the app and inside any Carton.

## Examples

The [README](../README.md#docs) lists every example. Run one with
`RUBY_BOX=1 ruby examples/<name>/main.rb`.
