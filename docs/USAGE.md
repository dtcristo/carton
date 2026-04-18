# Usage

## Requirements

- Ruby 4.0+
- `RUBY_BOX=1`
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

### Named exports

Use keyword arguments when the file exports a small namespace.

```ruby
# math.rb
def add(a, b) = a + b

export(
  PI: 3.14159,
  version: '1.0.0',
  add: method(:add)
)
```

Importing named exports returns a `Carton::Exports` object, which behaves like a namespace module.

```ruby
MathTools = import_relative 'math'

MathTools::PI
MathTools.version
MathTools.add(2, 3)
```

`Carton::Exports` and bare `Carton::Box` imports share a small lookup API: `[]`, `fetch`, `fetch_values`, `values_at`, and `key?`.

Only one export call is allowed per imported file. Use `export_default value` for single exports or `export foo:, bar:` for named exports.

## Importing

### `import_relative`

`import_relative path` resolves relative to the calling file, like `require_relative`.

```ruby
User = import_relative 'user'
```

### `import`

`import path` resolves using the current box's `$LOAD_PATH` or an absolute path.

```ruby
Quest = import 'quest'
Widget = import '/absolute/path/to/widget.rb'
```

When you want `import 'name'` to work across local cartons, add their `lib/` directories to `$LOAD_PATH` first.

```ruby
cartons_dir = File.expand_path('cartons', __dir__)

Dir.glob(File.join(cartons_dir, '*/lib')).sort.each do |dir|
  $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir)
end
```

The complex example keeps that setup explicit in `examples/complex/main.rb`.

## Destructuring

Named exports support pattern matching through `deconstruct_keys`.

```ruby
import_relative('math') => { add:, version: }

add.(2, 3)
version
```

You can rename during destructuring:

```ruby
import_relative('math') => { add: sum }
sum.(10, 10)
```

## Constants

For exported constants, the simplest options are namespace access, `[]`, or `fetch`.

```ruby
MathTools = import_relative 'math'
PI = MathTools::PI
```

```ruby
PI = import('math')[:PI]
```

For multiple values:

```ruby
PI, version = import_relative('math').fetch_values(:PI, :version)
```

## Bare imports

If a file does not call `export`, importing it returns the `Carton::Box` itself.

```ruby
Toolbox = import 'some_script'

Toolbox::SomeConstant
Toolbox.fetch(:helper)
```

## Bundler inside cartons

The library works with or without Bundler. Plain cartons need no extra setup. For a bundled carton, do the RubyGems/Bundler setup inside that carton's entry file.

```ruby
# cartons/adventure/lib/adventure.rb
Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

require 'dotenv'
export_default Dotenv
```

Then import the carton normally:

```ruby
Adventure = import 'adventure'
```

`Carton.bootstrap_rubygems!` installs Carton's box-local RubyGems patch in the current box. `Carton.with_bundle` only scopes `BUNDLE_GEMFILE` and `BUNDLE_LOCKFILE` for the block, so `require 'bundler/setup'` still uses Bundler's own Gemfile/lockfile discovery rules. With no argument, `with_bundle` searches upward from the calling file for `gems.rb` or `Gemfile`.

Current limits:

- bundled cartons work best from an unbundled parent process
- treat `bundle exec` as unsupported when a box will activate its own bundle
- `Gem.loaded_specs` is still shared enough that Carton snapshots/restores it at the import boundary after a bootstrapped boxed import

See [HOW_GEMS_WORK.md](HOW_GEMS_WORK.md) for the runtime background and [RUBYGEMS_UPSTREAM.md](RUBYGEMS_UPSTREAM.md) for the minimal upstream plan.

## Examples

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
RUBY_BOX=1 bundle exec rake example:complex
```

See the example READMEs for details:

- [examples/minimal/README.md](examples/minimal/README.md)
- [examples/complex/README.md](examples/complex/README.md)
