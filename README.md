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

Ruby apps draw boundaries with folders and namespaces. Ruby ignores them. Any file can reach any top-level constant, a patch to a builtin class applies everywhere, and one Gemfile picks one version of each gem for the whole app. In a big app, that's how a money helper in Billing changes what Shipping prints.

Carton makes them real. Each Carton is a boundary that only its export can cross. It has its own dependencies and runs in a separate [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html), so Ruby enforces the boundary at runtime:

- other Cartons reach **only what a Carton exports**;
- **monkey patches to builtin classes** stay in the Carton that makes them;
- two Cartons can use **different versions of the same gem**.

Cartons still talk through method calls in one process, not network calls. A Carton is shaped like a gem: `billing.rb` plus the `billing/` directory beside it. There is no manifest, and with a gemspec a Carton can leave the app as a gem.

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

Carton is experimental, and so is `Ruby::Box`. [Status](https://carton.dtcristo.com/start/status/) lists what must change before production, and [Why Carton](https://carton.dtcristo.com/start/why-carton/) covers what a Box does not isolate and where Carton fits today. Rails and Hanami work experimentally; see the [Rails](https://carton.dtcristo.com/guides/examples/rails/) and [Hanami](https://carton.dtcristo.com/guides/examples/hanami/) examples.

## Docs

Guides and reference live at [carton.dtcristo.com](https://carton.dtcristo.com) (source in [website/](website/README.md)). Start with:

- [Getting started](https://carton.dtcristo.com/start/getting-started/)
- [Why Carton](https://carton.dtcristo.com/start/why-carton/)
- [Status](https://carton.dtcristo.com/start/status/)
- [Adopting Carton](https://carton.dtcristo.com/guides/adopting/) in an existing app
- [Examples](https://carton.dtcristo.com/guides/examples/): runnable apps, starting with [minimal](https://carton.dtcristo.com/guides/examples/minimal/); run one with `bundle exec rake example:<name>`

For contributors:

- [design.md](docs/design.md), [performance.md](docs/performance.md), [todo.md](docs/todo.md), and [internals/](docs/internals/)
- [CONTEXT.md](CONTEXT.md): the glossary

The `carton` command, for RBS and boundary checks, is in the [`carton-tools`](carton-tools/README.md) gem. The [Tooling example](https://carton.dtcristo.com/guides/examples/tooling/) runs those commands and checks an app with Steep.

## Development

```sh
bundle install
bundle exec rake        # tests, RuboCop, and every example
bundle exec rake format # format with Syntax Tree
```

## License

Available as open source under the [MIT License](https://opensource.org/licenses/MIT).
