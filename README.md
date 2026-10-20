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

Split an app into Cartons that import and export like modules. Each Carton runs in its own [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html), so Ruby enforces the boundary while your code runs:

- other Cartons reach **only what a Carton exports**;
- **monkey patches to builtin classes** stay in the Carton that makes them;
- two Cartons can use **different versions of the same gem**.

A Carton is shaped like a gem: `billing.rb` plus the `billing/` directory beside it. There is no manifest, and with a gemspec a Carton can leave the app as a gem.

## Quick start

Carton needs Ruby 4.0.7+ with Boxes enabled (`RUBY_BOX=1`).

```sh
gem install carton   # or add `gem 'carton'` to your Gemfile
```

```ruby
# tax.rb: the tax Carton
module Tax
  def self.on(total) = total / 10
end

export Tax # the one value importers get
```

```ruby
# billing.rb: the billing Carton
Tax = import_relative 'tax' # billing's import, invisible to importers

module Billing
  def self.invoice(total) = total + Tax.on(total)
end

export Billing
```

```ruby
# main.rb
require 'carton'

Billing = import_relative 'billing'
Billing.invoice(100) # => 110
Tax                  # NameError: billing's import
```

```sh
RUBY_BOX=1 ruby main.rb
```

## Status

Carton is experimental, and so is `Ruby::Box`. Box isolates definitions and load state, not objects, so it is not a security boundary, and classes a Carton exports are shared with every importer. [Why Carton](https://carton.dtcristo.com/project/why-carton/) compares it with Bundler and Packwerk and covers where it fits today.

## Docs

Guides and reference live at [carton.dtcristo.com](https://carton.dtcristo.com) (source in [website/](website/README.md)). For contributors:

- [design.md](docs/design.md), [performance.md](docs/performance.md), [todo.md](docs/todo.md), and [internals/](docs/internals/)
- [CONTEXT.md](CONTEXT.md): the glossary
- [examples/](examples/README.md): runnable apps, starting with [minimal](examples/minimal/README.md); run one with `bundle exec rake example:<name>`

The `carton` command, for RBS and boundary checks, is in the [`carton-tools`](carton-tools/README.md) gem.

## Development

```sh
bundle install
bundle exec rake        # tests, RuboCop, and every example
bundle exec rake format # format with Syntax Tree
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
