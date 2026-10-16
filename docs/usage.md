# Usage

## Requirements

- Ruby 4.0.7+
- Bundler 4.0.23+ if you use Bundler
- `RUBY_BOX=1` in the environment, e.g. `RUBY_BOX=1 ruby main.rb`
- `require 'carton'` before using `import`, `import_relative`, `export_default`, or `export`

In Carton, an importable package is called a carton. This guide still says "package" sometimes in plain English, but "carton" is the project term.

## Exporting

### Single export

Use a single export when the file represents one main thing.

```ruby
# user.rb
class User
  def initialize(name) = @name = name

  def greet = "Hello, #{@name}!"
end

export_default User
```

Importing that file returns the exported object itself:

```ruby
User = import_relative 'user'
User.new('Alice').greet
```

The Default Export may be any object, including a Hash, `nil`, or `false`.
A Hash remains the Default Export itself; only `export` creates an Export
Namespace.

### Named exports

Use `export` when the file exports a small namespace. Symbols name top-level
methods; keyword arguments are plain values.

```ruby
# math.rb
def add(a, b) = a + b

export :add, PI: 3.14159, version: '1.0.0'
```

Importing named exports returns a `Carton::Exports` object, which behaves like a namespace module.

```ruby
$LOAD_PATH.unshift(__dir__)
MathTools = import 'math'

MathTools::PI
MathTools.version
MathTools.add(2, 3)
MathTools[:add] # => #<Method: ...add(a, b)>
```

- `MathTools.add(...)` forwards arguments, keywords, and blocks to the method.
- `[]`, `fetch`, and destructuring return the `Method` object.
- Keyword values are never invoked: `export handler: -> {}` makes
  `handler` return the lambda itself.
- A symbol naming a missing method raises `NameError` at export time.
- A name given both as a symbol and as a keyword raises `ArgumentError`.

`Carton::Exports` and bare `Carton::Box` imports share a small lookup API: `[]`, `fetch`, `fetch_values`, `values_at`, and `key?`.

Only one export call is allowed per imported file. Use `export_default value` for single exports or `export :name, key: value` for named exports.

## Importing

### `import_relative`

`import_relative path` resolves relative to the calling file, like `require_relative`.

```ruby
User = import_relative 'user'
```

### `import`

`import path` resolves using the current box's `$LOAD_PATH` or an absolute path.

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
rest.keys # => [:PI, :add, :nothing, :subtract]
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

If a file does not call `export`, importing it returns the `Carton::Box` itself.

```ruby
Toolbox = import 'some_script'

Toolbox::SomeConstant
Toolbox.fetch(:helper).call
```

Bare lookup includes only top-level constants and helpers introduced by the
Carton's Entrypoint. It excludes inherited runtime constants and Box methods.
Keys are names, not Ruby expressions. Helper lookups return the `Method`
object, so `[]`, `fetch`, `key?`, and destructuring never invoke a helper.
Bare Carton hash-rest patterns enumerate that same Public Surface.

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

Bundler finds its Gemfile through process-global `ENV`, so `setup_bundle` sets
`BUNDLE_GEMFILE`, clears any stale `BUNDLE_LOCKFILE`, and restores both
afterwards. Bundler keeps the Gemfile it selected, so a later
`Bundler.require` in the same Carton still uses it.

`RUBY_BOX=1 bundle exec ruby main.rb` also works, including when the Gemfile
evaluates a gemspec.

See [how-gems-work.md](internals/how-gems-work.md) for the runtime background and [rubygems-upstream.md](internals/rubygems-upstream.md) for the minimal upstream plan.

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
