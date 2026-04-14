# Ruby Package

Small wrapper around [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html) that makes isolated imports and exports feel like part of Ruby. Requires Ruby 4.0+ and `RUBY_BOX=1`.

## Why

Use this when plain `require` is too global but a full gem boundary is heavier than you want. Package lets one file or local package expose a small public surface without leaking helper methods, constants, monkey patches, or bundle setup into the caller.

It fits plugin-like code, local packages inside one repo, and scripts or examples that want a simple import/export shape. Use a single export when the file is "one main thing", named exports for a small namespace, and `Package.with_bundle` when the imported package needs its own Gemfile.

## Minimal usage

```ruby
# user.rb
class User
  def initialize(name) = @name = name
end

export User
```

```ruby
# main.rb
require 'package'

User = import_relative 'user'
alice = User.new('Alice')
```

Named exports return a namespace-like module:

```ruby
# math.rb
def add(a, b) = a + b

export PI: 3.14159, add: method(:add)
```

```ruby
MathTools = import_relative 'math'
MathTools::PI
MathTools.add(2, 3)
```

## Docs

- [USAGE.md](USAGE.md) - detailed import/export, load path, and Bundler usage
- [DESIGN.md](DESIGN.md) - implementation overview and constraints
- [TODO.md](TODO.md) - future improvements and Bundler upstream ideas
- [examples/minimal/README.md](examples/minimal/README.md) - smallest example
- [examples/complex/README.md](examples/complex/README.md) - multi-package example

## Development

```sh
bundle install
RUBY_BOX=1 bundle exec rake
bundle exec rake format
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
