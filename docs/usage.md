# Usage

## Requirements

- Ruby 4.0.7+
- Bundler 4.0.23+ if you use Bundler
- `RUBY_BOX=1` in the environment, e.g. `RUBY_BOX=1 ruby main.rb`
- `require 'carton'` before using `import`, `import_relative`, `export`, or `export_default`

An importable Ruby file and everything it loads is called a carton. Each
carton runs in its own `Ruby::Box`, so its constants, gems, and monkey patches
stay inside, and only what it exports crosses the boundary. See
[CONTEXT.md](../CONTEXT.md) for the full glossary.

## Exporting

`export` adds names to the Carton's Export Namespace. Call it as often as
you like; each name may be exported once.

```ruby
# pricing.rb
class Money
end
export :Money                     # a capitalized Symbol names a constant

export def add(a, b) = a + b      # `def` returns :add, like `private def`

export PI: 3.14159, version: '1.0.0'
```

- A capitalized Symbol exports the top-level constant of that name; any other
  Symbol exports the top-level method. Both are looked up when `export`
  runs, so export after defining, as with `private` or `private_constant`.
- Keyword arguments export plain values. Capitalized keys become constants
  and lowercase keys become readers. Values are never invoked:
  `export handler: -> {}` makes `handler` return the lambda itself.
- A missing method or constant raises `NameError`, and a repeated name
  raises `ArgumentError`, at the `export` call.
- `export def name ...` returns `:name`, so it composes like `private def`.

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

Use `export_default` when a file represents one main thing, typically a
class or a root namespace module. Importing the file returns that value
itself:

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
- Call it once per file, and do not combine it with `export`; both raise.
  Put other names inside the default value instead, e.g. `User::VERSION`.
- Bind it to its own name (`User = import 'user'`). Rename only to resolve
  a clash between Cartons: `Module#name`, `inspect`, and backtraces keep
  the original name.

### Exporting a gem's root module

Make the root module the Default Export and keep internals private with
Ruby's own `private_constant`, which holds across Boxes:

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

`export` only declares exports from the file being imported. Anywhere else
it still checks its arguments, then does nothing. A file loaded with
`require`, whether by an app that never imports or by another Carton,
ignores its own `export` and `export_default` lines. A gem can add
`export_default MyGem` and keep working for apps that just
`require 'my_gem'` (it needs `require 'carton'` first so the methods exist).

## Importing

### `import_relative`

`import_relative path` resolves relative to the calling file, like `require_relative`. A missing file raises `LoadError`; it never falls back to a same-named feature on `$LOAD_PATH`.

```ruby
User = import_relative 'user'
```

### `import`

`import path` resolves an absolute path, or searches the current box's `$LOAD_PATH` like `require`. It does not check the current directory. A missing absolute path or name raises `LoadError`.

```ruby
MathTools = import 'math_tools'
Widget = import '/absolute/path/to/widget.rb'
```

When you want `import 'name'` to work across local cartons, add their `lib/` directories to `$LOAD_PATH` first.

```ruby
cartons_dir = File.expand_path('cartons', __dir__)

Dir.glob(File.join(cartons_dir, '*/lib')).sort.each do |dir|
  $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)
end
```

The bundler example keeps that setup explicit in `examples/bundler/main.rb`.

### Rakefiles

Rake defines its own `import` on the Rakefile's top-level object, which shadows Carton's. Use `import_relative` in a Rakefile, or call `import` from inside a class or method.

### Shared imports

Each carton file loads once per process. Later imports of the same file return the same value, whether they come from the app or from another carton, and whether they use `import`, `import_relative`, or an absolute path. Sibling cartons that import the same carton therefore share its classes, so `is_a?` checks work across them.

```ruby
Money = import 'money'
Money.equal?(import('money')) # => true
```

If a carton fails to load, Carton does not cache the failure, so a later import tries again. A carton that imports itself, directly or through other cartons, raises `circular import`.

## Destructuring

Export Namespaces and Bare Cartons support pattern matching through
`deconstruct_keys`.

```ruby
import('math') => { add:, version: }

add.(2, 3)
version
```

You can rename during destructuring:

```ruby
import('math') => { add: sum }
sum.(10, 10)
```

Hash-rest patterns enumerate the entire public surface. For an Export Namespace,
that is every Named Export.

```ruby
import('math') => { version:, **rest }
rest.keys # => [:add, :PI]
```

## Constants

For exported constants, the simplest options are namespace access, `[]`, or `fetch`.

```ruby
MathTools = import 'math'
PI = MathTools::PI
```

```ruby
PI = import('math')[:PI]
```

For multiple values:

```ruby
PI, version = import('math').fetch_values(:PI, :version)
```

## Bare imports

If a file does not call `export`, importing it returns a `Carton::Exports`
holding the constants and top-level helpers the file defines, as if it had
exported them all. The Carton's Box stays private, so an importer cannot
`eval` or `require` inside it.

```ruby
Toolbox = import 'some_script'

Toolbox::SomeConstant
Toolbox.helper
Toolbox.fetch(:helper).call
```

Constants are read when the import finishes, so an autoloaded top-level
constant loads then rather than on first use.

Bare lookup includes only top-level constants and helpers introduced by the
Carton's Entrypoint. It excludes inherited runtime constants and Box methods.
Keys are names, not Ruby expressions. Helper lookups return the `Method`
object, so `[]`, `fetch`, `key?`, and destructuring never invoke a helper.
Bare Carton hash-rest patterns enumerate that same Public Surface.

## Sharing classes across cartons

Boxes isolate monkey patches to builtin classes: patching `String` in one
carton does not change `String` anywhere else. Classes a carton defines are
different. An exported class is one object with one definition, shared by
every importer, as in ordinary Ruby. Reopening it from another carton,
including `class Customer` in a box where `Customer` names the imported
class, changes it for every carton.

Box is not a security boundary, so this cannot be prevented outright. These
habits avoid it by accident:

- **Subclass instead of reopening.** Give each carton its own base classes
  rather than binding a shared one to a bare name:

  ```ruby
  # customers/lib/customers.rb
  class ApplicationRecord < Framework::ApplicationRecord # this carton's own class
    self.abstract_class = true
  end
  ```

  Changes to a subclass never reach its parent.
- **Refine to extend another carton's class.** A refinement applies only to
  files that `using` it, so the owning carton never sees it.
- **Freeze plain-Ruby exports.** `export_default Pricing.freeze` makes any
  reopen raise `FrozenError` while still allowing subclasses. Do not freeze
  Active Record models or their base classes: Rails writes class-level state
  at runtime, so even `create!` raises once a model's class is frozen.

See [how-boxes-work.md](internals/how-boxes-work.md#which-classes-get-per-box-copies-ruby-407)
for why only builtins get per-box copies.

## Testing cartons

Tests run in the Main Box, so a test imports a carton the same way an app does. Run them with `RUBY_BOX=1`.

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

Imports are shared across the process, so carton state persists from one test to the next. Keep cartons stateless, or reset their state through their public surface.

A test sees only the carton's public surface. A bare carton exposes its top-level constants and helpers, so a test can reach those. To test internals of a carton that exports, move them into their own carton file and import that file directly.

## Bundler inside cartons

The library works with or without Bundler. A Carton that needs Bundler sets up its own bundle inside its Entrypoint; other Cartons need no setup. Each Box has its own RubyGems state, so a Carton's gems never leak into its caller.

```ruby
# cartons/math_helper/lib/math_helper.rb
Carton.setup_bundle

# `require` exposes BigDecimal directly in this carton.
require 'bigdecimal'

export version: BigDecimal::VERSION, number_type: BigDecimal.name
```

Then import the carton normally:

```ruby
MathHelper = import 'math_helper'
MathHelper.number_type
```

The top-level app uses the same line. `Carton.setup_bundle` works like
`Bundler.setup`: pass groups to set up only those, e.g.
`Carton.setup_bundle(:default, :test)`. By default it searches upward from the
calling file for `gems.rb` or `Gemfile`; pass `gemfile:` (relative to the
calling file) to choose one. It raises `Carton::GemfileNotFound` when there is
no Gemfile, and Bundler errors raise instead of exiting.

`ENV` is shared by the whole process. Bundler reads its Gemfile from
`BUNDLE_GEMFILE` and exports variables such as `RUBYOPT` for subprocesses, so
`setup_bundle` points `BUNDLE_GEMFILE` at the Carton's Gemfile, then restores
all of `ENV` when setup finishes. Bundler keeps the Gemfile it selected, so a
later `Bundler.require` in the same Carton still uses it.

While `setup_bundle` runs, other threads can see the Carton's `BUNDLE_GEMFILE`
and Bundler's exported variables; Carton cannot make `ENV` thread-local. Call
`setup_bundle` while booting, before starting threads that read `ENV`.

Restoring `ENV` means subprocesses never inherit a Carton's bundle, including
ones the Carton starts itself. Wrap a subprocess that needs the bundle in
`bundle exec`, or pass it `BUNDLE_GEMFILE`.

`RUBY_BOX=1 bundle exec ruby main.rb` also works, including when the Gemfile
evaluates a gemspec.

### Gem cartons

Importing a file that belongs to a gem the caller has activated, such as a
path gem in the app's Gemfile, activates that gem and its runtime dependencies
in the Carton's Box at the caller's versions. The gem needs no Gemfile of its
own:

```ruby
# Gemfile: gem 'bigdecimal', '3.3.1'; gem 'pricing', path: 'pricing'
Carton.setup_bundle
Pricing = import 'pricing' # pricing's `require 'bigdecimal'` gets 3.3.1
```

A gem Carton loads once per process, so its first importer fixes its gem
versions. A later importer whose activated versions differ raises
`RuntimeError` naming the gem and both versions, instead of silently sharing
a Carton built against another version. If the gem Carton also calls
`setup_bundle`, its Gemfile must agree with the caller's versions, or Bundler
raises `Gem::LoadError`.

When the caller ran Bundler setup (`Carton.setup_bundle`, `bundler/setup`, or
`bundle exec`), the gem Carton's Box is restricted to the caller's bundle, as
`Bundler.setup` restricts Main. Every locked gem loads at its locked version,
even one the gemspec forgot to declare, and a gem outside the lockfile raises
`LoadError`.

Without Bundler, only declared dependencies the caller activated are shared,
and anything else falls back to RubyGems picking the newest installed version
inside the Box.

See [how-gems-work.md](internals/how-gems-work.md) for the runtime background and [upstream.md](internals/upstream.md) for upstream status.

## Examples

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
RUBY_BOX=1 ruby examples/gems/main.rb
RUBY_BOX=1 ruby examples/bundler/main.rb
```

The Bundler example is the repository-level path-gem and nested-bundle
regression.

See the example READMEs for details:

- [examples/minimal/README.md](../examples/minimal/README.md)
- [examples/gems/README.md](../examples/gems/README.md)
- [examples/bundler/README.md](../examples/bundler/README.md)
