<div align="center">
  <img src="images/carton.png" alt="Carton logo" width="200" />
  <h1>
    Carton
  </h1>
  <p>
    <strong>
      Easily box your Ruby
    </strong>
  </p>
</div>

Carton is a thin wrapper around [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html) for safe, ergonomic modularization in Ruby 4.0.7+. It gives you imports and exports that work like ES Modules while still feeling like Ruby. Each carton can isolate constants, gems and monkey patches behind a small public API, so large apps can keep clear boundaries.

## Install

```sh
gem install carton   # or add `gem 'carton'` to your Gemfile
```

Carton needs Ruby 4.0.7+ with boxes enabled, so run your app with `RUBY_BOX=1`:

```sh
RUBY_BOX=1 ruby main.rb
```

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

Without a default, `export` builds a namespace-like module. Call it as often
as you like: capitalized Symbols export constants, other Symbols export
methods, and keywords export plain values.

```ruby
# math.rb
export def add(a, b) = a + b
export PI: 3.14159
```

```ruby
MathTools = import_relative 'math'
MathTools::PI
MathTools.add(2, 3)
```

## Docs

- [usage.md](docs/usage.md) - imports, exports, load paths, Bundler, and testing
- [design.md](docs/design.md) - implementation overview and constraints
- [todo.md](docs/todo.md) - planned library, docs, and tooling work
- [examples/minimal](examples/minimal/README.md) - smallest example
- [examples/gems](examples/gems/README.md) - manual RubyGems activation without Bundler
- [examples/bundler](examples/bundler/README.md) - per-Carton Bundler setup plus a support gem
- [examples/rails](examples/rails/README.md) - Rails app with domain logic in a Zeitwerk Carton

Research notes on `Ruby::Box`, RubyGems, Bundler, and upstream plans live in [docs/internals](docs/internals/).

## Development

```sh
bundle install                              # Install development deps
bundle exec rake                            # Run tests, lint, and examples
bundle exec rake format                     # Format code
bundle exec rake rubocop                    # Lint code
RUBY_BOX=1 ruby examples/minimal/main.rb     # Run the minimal example
RUBY_BOX=1 ruby examples/gems/main.rb        # Run the RubyGems example
RUBY_BOX=1 ruby examples/bundler/main.rb     # Run the Bundler example
RUBY_BOX=1 ruby examples/rails/main.rb       # Run the Rails example
```

A carton with its own Gemfile calls `Carton.setup_bundle`; see
[usage.md](docs/usage.md#bundler-inside-cartons). Bundler support needs
Bundler 4.0.23+, and `RUBY_BOX=1 bundle exec` works.

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
