<div align="center">
  <h1>
    Carton
  </h1>
  <img src="images/carton.png" alt="Carton logo" width="200" />
  <p>
    <strong>
      Easily box your Ruby
    </strong>
  </p>
</div>

Carton is a thin wrapper around [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html) for safe, ergonomic modularization in Ruby 4.0.6+. It gives you imports and exports that work like ES Modules while still feeling like Ruby. Each carton can isolate constants, gems and monkey patches behind a small public API, so large apps can keep clear boundaries.

## Minimal usage

```ruby
# user.rb
class User
  def initialize(name) = @name = name
end

export_default User
```

```ruby
# main.rb
require 'carton'

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
require 'carton'

MathTools = import_relative 'math'
MathTools::PI
MathTools.add(2, 3)
```

## Docs

- [usage.md](docs/usage.md) - detailed import/export, caller load path, and explicit Bundler bootstrap
- [design.md](docs/design.md) - implementation overview and constraints
- [how-gems-work.md](docs/how-gems-work.md) - deep guide to RubyGems, Bundler, activation, and boxes
- [how-boxes-work.md](docs/how-boxes-work.md) - deep guide to `Ruby::Box` internals and sharp edges
- [rubygems-upstream.md](docs/rubygems-upstream.md) - minimal RubyGems/Bundler upstream plan
- [ruby-upstream.md](docs/ruby-upstream.md) - minimal Ruby upstream plan
- [todo.md](docs/todo.md) - future library, docs, and tooling work
- [examples/minimal/README.md](examples/minimal/README.md) - smallest example
- [examples/gems/README.md](examples/gems/README.md) - manual RubyGems activation without Bundler
- [examples/bundler/README.md](examples/bundler/README.md) - per-Carton Bundler setup plus a support gem

## Development

```sh
bundle install                              # Install development deps
bundle exec rake format                     # Format code
bundle exec rake rubocop                    # Lint code
RUBY_BOX=1 ruby examples/minimal/main.rb     # Run the minimal example
RUBY_BOX=1 ruby examples/gems/main.rb        # Run the RubyGems example
```

The boxed path-gem and Bundler prelude regressions require revalidation on Ruby 4.0.6.

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
