# Usage

## Requirements

- Ruby 4.0+
- `RUBY_BOX=1`
- `require 'package'` before using `import`, `import_relative`, `export_default`, or `export`

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

Importing named exports returns a `Package::Exports` object, which behaves like a namespace module.

```ruby
MathTools = import_relative 'math'

MathTools::PI
MathTools.version
MathTools.add(2, 3)
```

`Package::Exports` and bare `Package::Box` imports share a small lookup API: `[]`, `fetch`, `fetch_values`, `values_at`, and `key?`.

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

When you want `import 'name'` to work across local packages, add their `lib/` directories to `$LOAD_PATH` first.

```ruby
packages_dir = File.expand_path('packages', __dir__)

Dir.glob(File.join(packages_dir, '*/lib')).sort.each do |dir|
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

If a file does not call `export`, importing it returns the `Package::Box` itself.

```ruby
Toolbox = import 'some_script'

Toolbox::SomeConstant
Toolbox.fetch(:helper)
```

## Bundler inside packages

The library works with or without Bundler. Plain packages need no extra setup. For a bundled package, the reliable pattern today is still: select the Gemfile around the `import` that loads that package.

```ruby
gemfile = File.expand_path('packages/adventure/Gemfile', __dir__)

Adventure = Package.with_bundle(gemfile) { import 'adventure' }
```

`Package.with_bundle` is just a small wrapper around the same `BUNDLE_GEMFILE` handoff. The underlying constraint is still Bundler's: `bundler/setup` discovers the active Gemfile from env/process state, and RubyGems activation state (`Gem.loaded_specs`) is still shared across boxes in practice, so conflicting bundles still cannot be switched reliably in one process today.

Current limits:

- one package-local bundle can be activated cleanly from an unbundled parent
- a bundled parent process is not a reliable place to import a child package with its own bundle
- conflicting bundles in one process still need a subprocess workaround

See [TODO.md](TODO.md) for the upstream Bundler work that would make this cleaner.

## Examples

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
RUBY_BOX=1 bundle exec rake example:complex
```

See the example READMEs for details:

- [examples/minimal/README.md](examples/minimal/README.md)
- [examples/complex/README.md](examples/complex/README.md)
