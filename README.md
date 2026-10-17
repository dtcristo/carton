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

Carton adds `import` and `export` to Ruby, built on
[`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html). Each imported
file, called a Carton, loads in its own Box. Its constants, gems, and monkey
patches stay inside, and only what it exports reaches the importer.

- **Explicit boundaries.** Only `import` crosses into a Carton, and only its
  exports come back.
- **Gem isolation.** Two Cartons can use different versions of the same gem in
  one process, each with its own Bundler setup if it wants one.
- **Contained monkey patches.** Patching `String` in one Carton leaves every
  other Carton alone.
- **Plain Ruby.** Any file can be a Carton, and Ruby's own `private_constant`
  hides internals. Carton has no manifest or directory layout.

## Quick start

Carton needs Ruby 4.0.7+ with Boxes enabled (`RUBY_BOX=1`). The API below is
on `main` and not yet released, so install from GitHub:

```ruby
# Gemfile
gem 'carton', github: 'dtcristo/carton'
```

Export one main value with `export_default`:

```ruby
# user.rb
class User
  def initialize(name) = @name = name
end

export_default User
```

Or export several names with `export`. Capitalized Symbols name constants,
other Symbols name methods, and keywords are plain values:

```ruby
# math.rb
export def add(a, b) = a + b
export PI: 3.14159
```

Import them:

```ruby
# main.rb
require 'carton'

User = import_relative 'user'
User.new('Alice')

MathTools = import_relative 'math'
MathTools.add(2, 3) # => 5
MathTools::PI       # => 3.14159
```

```sh
RUBY_BOX=1 ruby main.rb
```

`import 'name'` searches `$LOAD_PATH` like `require`, so gems and path gems
import by name. Each Carton loads once per process, and every later import
returns the same value.

## Gems and Bundler

A Carton can set up its own bundle, isolated from the app's:

```ruby
# cartons/reports/lib/reports.rb
Carton.setup_bundle # uses cartons/reports/Gemfile
require 'bigdecimal'
```

A gem in the app's bundle imports as a Carton and gets its dependencies at the
app's locked versions. For a monorepo, make each package a path gem in one
Gemfile and import it by name; see [examples/monorepo](examples/monorepo/README.md).

## Status

Carton is experimental, and so is `Ruby::Box`. It targets Ruby 4.0.7+ and,
with Bundler, Bundler 4.0.23+. Box is not a security boundary: it isolates
definitions and load state, not objects. Classes a Carton defines are shared
with every importer, so reopening one changes it everywhere; see
[Sharing classes across Cartons](docs/usage.md#sharing-classes-across-cartons).

## Docs

- [usage.md](docs/usage.md): exports, imports, Bundler, gem Cartons, and testing
- [design.md](docs/design.md): how an import runs
- [todo.md](docs/todo.md): planned work and open questions
- [internals/](docs/internals/): how `Ruby::Box`, RubyGems, and Bundler work, and upstream plans
- [CONTEXT.md](CONTEXT.md): the glossary

Examples, each runnable with `RUBY_BOX=1 ruby examples/<name>/main.rb`:

| Example | Shows |
| --- | --- |
| [minimal](examples/minimal/README.md) | `export_default`, `export`, and `import_relative`, with no gems |
| [gems](examples/gems/README.md) | Two Cartons using different `bigdecimal` versions without Bundler |
| [bundler](examples/bundler/README.md) | Cartons with their own Bundler setup, plus a path gem |
| [monorepo](examples/monorepo/README.md) | Packages as path gems in one Gemfile, imported by gem name |
| [rails_in_main](examples/rails_in_main/README.md) | Rails in the Main Box, domain logic in a Carton |
| [rails_in_cartons](examples/rails_in_cartons/README.md) | Rails loaded once in a Carton, models and controllers in domain Cartons |
| [master_prelude](examples/master_prelude/README.md) | An unsupported hack that shares Active Support with every Carton |

## Development

```sh
bundle install
bundle exec rake                  # tests, RuboCop, and every example
bundle exec rake test             # tests only
bundle exec rake example:monorepo # one example
bundle exec rake format           # format with Syntax Tree
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
