<div align="center">
  <img src="images/carton.png" alt="Carton logo" width="200" />
  <h1>
    Carton
  </h1>
  <p>
    <strong>
      Real boundaries for Ruby
    </strong>
  </p>
</div>

Ruby has gems to share code and Bundler to pick their versions, but nothing inside an app draws a boundary. Every file loads into one namespace: any code can reach any constant, a monkey patch applies everywhere, and one Gemfile fixes one version of each gem for the whole process. A boundary is a convention.

Carton is the package system Ruby has been missing. Split code into Cartons that import and export like modules. Each Carton runs in its own [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html), so Ruby enforces the boundary while the code runs:

- other Cartons reach **only what a Carton exports**;
- **monkey patches to builtin classes**, such as `String#blank?`, stay in the Carton that makes them;
- two Cartons can use **different versions of the same gem**.

A Carton is shaped like a gem: `billing.rb` plus the `billing/` directory, with no manifest. A gem, a path gem, a directory, or a single file can be one, and a Carton with a gemspec can leave the app as a published gem unchanged.

A Box does not isolate everything. Classes and objects a Carton exports are shared, not copied, so reopening an exported class or changing a shared object affects every importer. A plain `require` of a Carton's files loads a Second Copy outside its boundary, which `carton check` reports. And each Carton loads once per process: its state lasts as long as the process, and its First Importer fixes its gem versions.

## Why Carton

| | Bundler | [Packwerk](https://github.com/Shopify/packwerk) | Carton |
| --- | --- | --- | --- |
| Boundaries inside an app | No | Checked statically, in CI | Enforced at runtime, and checked statically by `carton check` |
| Private internals | No | Privacy checks removed in 3.0 | Only exports cross; `private_constant` hides the rest |
| Constants loaded dynamically | n/a | Not seen | Inside the boundary like any other |
| Gem versions | One per app | One per app | One per Carton |
| Monkey patches to builtins | Global | Global | Stay in their Carton |
| Unit of distribution | A gem | A pack, which stays in the app | A gem-shaped Carton, which can become a gem |

Static checks only see what they can parse. Packwerk's authors note that a package with zero violations "may actually crash with name errors when its code is executed" ([A Packwerk Retrospective](https://shopify.engineering/a-packwerk-retrospective)). A Carton's boundary is the Box it runs in, so what `carton check` reports ahead of time is also what Ruby enforces.

## Where it fits today

- **The domains of an app or a monorepo**, as tens of Cartons. See [examples/monorepo](examples/monorepo/README.md), and [examples/rails_in_main](examples/rails_in_main/README.md) for domain Cartons beside a Rails app in the Main Box.
- **Plugin hosts whose plugins need conflicting gem versions**, which plain Ruby cannot load together; see [examples/plugins](examples/plugins/README.md).
- **Rails inside Cartons** works but is experimental: there is no reloading yet, and domain Cartons see Active Support's core extensions only if they load them ([examples/rails_in_cartons](examples/rails_in_cartons/README.md)).
- **Not yet file by file.** Each Carton costs about 60 ms and 2.4 MB ([performance.md](docs/performance.md)), most of it `Ruby::Box.new`, so aim for tens of Cartons, not hundreds.

## Quick start

Carton needs Ruby 4.0.7+ with Boxes enabled (`RUBY_BOX=1`). Install it:

```sh
gem install carton   # or add `gem 'carton'` to your Gemfile
```

A Carton's Entrypoint loads its own files and exports one value, usually its root module:

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

export Billing
```

Import it:

```ruby
# main.rb
require 'carton'

Billing = import_relative 'billing'
Billing.invoice(42)
```

```sh
RUBY_BOX=1 ruby main.rb
```

`import_relative 'billing/invoice'` raises `Carton::ImportError`: the file is in the `billing` Carton's Interior, so only `billing` can be imported. `import 'name'` searches `$LOAD_PATH` like `require`, so gems and path gems import by name, and a Gem-shaped Directory (`components/billing/lib/billing.rb`) imports by its path. Each Carton loads once per process, and every later import returns the same value.

## Gems and Bundler

A Carton can set up its own bundle, isolated from the app's:

```ruby
# cartons/reports/lib/reports.rb
Carton.setup_bundle # uses cartons/reports/Gemfile
require 'bigdecimal'
```

A gem in the app's bundle imports as a Carton and gets its dependencies at the app's locked versions. For a monorepo, make each Carton a path gem in one Gemfile and import it by name; see [examples/monorepo](examples/monorepo/README.md).

## Types and checks

The `carton` command, in the [`carton-tools`](carton-tools/README.md) gem, reads code without running it; add `gem 'carton-tools', group: :development` beside `carton`. `carton rbs main.rb` writes RBS so [Steep](https://github.com/soutaro/steep) knows what each import returns, and `carton check main.rb` reports missing imports, cycles, `require` calls that reach into a Carton, and Undeclared Gems in a Gem Carton. See [Types and checks](docs/usage.md#types-and-checks).

## Status

Carton is experimental, and so is `Ruby::Box`. It targets Ruby 4.0.7+ and, with Bundler, Bundler 4.0.23+. Box is not a security boundary: it isolates definitions and load state, not objects. Classes a Carton defines are shared with every importer, so reopening one changes it everywhere; see [Sharing classes across Cartons](docs/usage.md#sharing-classes-across-cartons).

## Docs

- [usage.md](docs/usage.md): exports, imports, Bundler, Gem Cartons, testing, types, and checks
- [design.md](docs/design.md): how an import runs
- [performance.md](docs/performance.md): import time and memory as Cartons and bundles grow
- [todo.md](docs/todo.md): planned work and open questions
- [internals/](docs/internals/): how `Ruby::Box`, RubyGems, and Bundler work, and upstream plans
- [CONTEXT.md](CONTEXT.md): the glossary

The [examples guide](examples/README.md) lists every example by the question it answers, explains setup, and separates application patterns from experiments. Start with [minimal](examples/minimal/README.md), then [exports](examples/exports/README.md) for other return values or [monorepo](examples/monorepo/README.md) for an app split into Cartons. Run `bundle exec rake example:<name>` to install its dependencies and run it.

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
