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
MathTools = import_relative 'math'
MathTools::PI
MathTools.add(2, 3)
```

## Docs

- [USAGE.md](USAGE.md) - detailed import/export, load path, and Bundler usage
- [DESIGN.md](DESIGN.md) - implementation overview and constraints
- [TODO.md](TODO.md) - future improvements and Bundler upstream ideas
- [examples/minimal/README.md](examples/minimal/README.md) - smallest example
- [examples/complex/README.md](examples/complex/README.md) - multi-carton example

## Development

```sh
bundle install                        # Install development deps
RUBY_BOX=1 bundle exec rake           # Run all tests and examples
bundle exec rake format               # Format code
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
