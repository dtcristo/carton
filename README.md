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

Carton is a thin wrapper around [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html) for safe, ergonomic modularization in Ruby 4+. It gives you imports and exports that work like ES Modules while still feeling like Ruby. Each carton can isolate constants, gems and monkey patches behind a small public API, so large apps can keep clear boundaries.

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

- [USAGE.md](docs/USAGE.md) - detailed import/export, caller load path, and explicit Bundler bootstrap
- [DESIGN.md](docs/DESIGN.md) - implementation overview and constraints
- [HOW_GEMS_WORK.md](docs/HOW_GEMS_WORK.md) - deep guide to RubyGems, Bundler, activation, and boxes
- [HOW_BOXES_WORK.md](docs/HOW_BOXES_WORK.md) - deep guide to `Ruby::Box` internals and sharp edges
- [RUBYGEMS_UPSTREAM.md](docs/RUBYGEMS_UPSTREAM.md) - minimal RubyGems/Bundler upstream plan
- [RUBY_UPSTREAM.md](docs/RUBY_UPSTREAM.md) - minimal Ruby upstream plan
- [TODO.md](docs/TODO.md) - future library, docs, and tooling work
- [examples/minimal/README.md](examples/minimal/README.md) - smallest example
- [examples/gems/README.md](examples/gems/README.md) - manual RubyGems activation without Bundler
- [examples/bundler/README.md](examples/bundler/README.md) - bundled cartons plus a support gem

## Development

```sh
bundle install                        # Install development deps
RUBY_BOX=1 bundle exec rake           # Run all tests and examples
bundle exec rake rubocop             # Lint code
bundle exec rake format               # Format code
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
