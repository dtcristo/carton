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
[`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html), for splitting
an app into gem-sized or domain-sized units. A Carton is a file plus the
directory named after it, the shape of a gem's `lib/`: `billing.rb` and
everything in `billing/`. It loads in its own Box, its constants, gems, and
monkey patches stay inside, and only what it exports reaches the importer.

- **Explicit boundaries.** Only `import` crosses into a Carton, only its
  Entrypoint can be imported, and only its exports come back.
- **Gem isolation.** Two Cartons can use different versions of the same gem in
  one process, each with its own Bundler setup if it wants one.
- **Contained monkey patches.** Patching `String` in one Carton leaves every
  other Carton alone.
- **Plain Ruby.** No manifest or required layout: a gem, a path gem, a
  directory, or a single file can be a Carton, and Ruby's own
  `private_constant` hides internals.

## Quick start

Carton needs Ruby 4.0.7+ with Boxes enabled (`RUBY_BOX=1`). Install it:

```sh
gem install carton   # or add `gem 'carton'` to your Gemfile
```

A Carton's Entrypoint loads its own files and exports one value with
`export_default`:

```
billing.rb          # the Entrypoint
billing/invoice.rb  # inside the Carton
```

```ruby
# billing.rb
require_relative 'billing/invoice'

module Billing
  def self.invoice(total) = Invoice.new(total)
end

export_default Billing
```

Or it exports several names with `export`. Capitalized Symbols name
constants, other Symbols name methods, and keywords are plain values:

```ruby
# math.rb
export def add(a, b) = a + b
export PI: 3.14159
```

Import them:

```ruby
# main.rb
require 'carton'

Billing = import_relative 'billing'
Billing.invoice(42)

MathTools = import_relative 'math'
MathTools.add(2, 3) # => 5
MathTools::PI       # => 3.14159
```

```sh
RUBY_BOX=1 ruby main.rb
```

`import_relative 'billing/invoice'` raises `Carton::ImportError`: the file is
inside the `billing` Carton, so only `billing` can be imported. `import 'name'`
searches `$LOAD_PATH` like `require`, so gems and path gems import by name, and
a gem-shaped directory (`components/billing/lib/billing.rb`) imports by its
path. Each Carton loads once per process, and every later import returns the
same value.

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
| [minimal](examples/minimal/README.md) | A Carton with its own directory, a single-file Carton, and the error for importing a file inside a Carton |
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
