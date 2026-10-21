---
title: Getting started
description: Install Carton, write your first Carton, and import it with Ruby Boxes enabled.
sidebar:
  order: 1
---

Carton splits an app into gem-sized or domain-sized Cartons. Each Carton runs in its own [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html), so its constants, gems, and monkey patches stay inside, and only what it exports crosses the boundary.

## Requirements

- Ruby 4.0.7 or later, run with Boxes enabled: `RUBY_BOX=1`
- Bundler 4.0.20 or later, if you use Bundler
- `require 'carton'` before the app first calls `import`, `import_relative`, or `export`; every Carton Box gets Carton automatically

## Install

```sh
gem install carton
```

Or add it to your Gemfile:

```ruby title="Gemfile"
gem 'carton'
```

## Write a Carton

A Carton's Entrypoint is a Ruby file that exports one value, usually its root module. Start with a tax Carton:

```ruby
# tax.rb: the tax Carton
module Tax
  def self.on(total) = total / 10
end

export Tax # the only value that leaves this Carton
```

## Import it

Cartons import each other. The billing Carton imports tax:

```ruby
# billing.rb: the billing Carton
Tax = import_relative 'tax' # billing's import, invisible to importers

module Billing
  def self.invoice(total) = total + Tax.on(total)
end

export Billing
```

The application imports billing from the Main Box:

```ruby
# main.rb
require 'carton'

Billing = import_relative 'billing' # runs billing.rb in its own Box
puts Billing.invoice(100)
```

Run it with Boxes enabled:

```sh
RUBY_BOX=1 ruby main.rb # prints 110
```

`import_relative` returns the exported value itself, and defines nothing in the importer. Bind it to a constant of the same name.

## See the boundary

Add a line to `main.rb` that reaches past billing:

```ruby
Tax # NameError: billing's import
```

In plain Ruby, a file's top-level constants are global, so requiring billing would make `Tax` visible everywhere. The billing Carton keeps its imports inside, along with every other top-level constant and helper it defines.

## Grow a Carton

When only billing uses tax, make it part of billing. A Carton is its Entrypoint plus its Interior, the directory named after it, shaped like a gem's `lib/`. Move `tax.rb` to `billing/tax.rb`, drop its `export`, and load it with `require_relative`:

```
billing.rb      # the Entrypoint
billing/tax.rb  # the Interior: inside the billing Carton
```

```ruby
# billing.rb
require_relative 'billing/tax' # loads inside billing's Box

module Billing
  def self.invoice(total) = total + Tax.on(total)
end

export Billing
```

`main.rb` still prints `110`, and `Tax` is still a `NameError` there. Only the Entrypoint can be imported, so `import_relative 'billing/tax'` raises `Carton::ImportError`.

Each Carton loads once per process, and every later import returns the same value. `import 'billing'` searches `$LOAD_PATH` like `require`, so gems and path gems import by name.

## Next steps

- [Cartons](/guides/cartons/): what belongs to a Carton, and how Zeitwerk fits.
- [Exporting](/guides/exporting/) and [Importing](/guides/importing/): the whole language.
- [Bundler](/guides/bundler/): give a Carton its own gems.
- [Examples](/guides/examples/): runnable apps, from the smallest boundary to plugins and Rails.
