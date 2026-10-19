---
title: Getting started
description: Install Carton, write your first Carton, and import it with Ruby Boxes enabled.
sidebar:
  order: 1
---

Carton splits an app into gem-sized or domain-sized units called Cartons. Each Carton runs in its own [`Ruby::Box`](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html), so its constants, gems, and monkey patches stay inside, and only what it exports crosses the boundary.

## Requirements

- Ruby 4.0.7 or later, run with Boxes enabled: `RUBY_BOX=1`
- Bundler 4.0.23 or later, if you use Bundler

## Install

```sh
gem install carton
```

Or add it to your Gemfile:

```ruby
# Gemfile
gem 'carton'
```

## Write a Carton

A Carton is an Entrypoint file plus the directory named after it. The Entrypoint loads the Carton's own files and exports one value, usually its root module:

```
billing.rb          # the Entrypoint
billing/invoice.rb  # the Interior: inside the billing Carton
```

```ruby
# billing/invoice.rb: inside the billing Carton
module Billing
  class Invoice
    def initialize(total) = @total = total
  end
end
```

```ruby
# billing.rb: the Entrypoint, which draws the boundary
require_relative 'billing/invoice'

module Billing
  def self.invoice(total) = Invoice.new(total)
end

export Billing # the only value that leaves this Carton
```

## Import it

```ruby
# main.rb: the application, in the Main Box
require 'carton'

Billing = import_relative 'billing' # runs billing.rb in its own Box
Billing.invoice(42)
```

Run it with Boxes enabled:

```sh
RUBY_BOX=1 ruby main.rb
```

`import_relative` returns the exported value itself, and defines nothing in the importer. Bind it to a constant of the same name.

## What the boundary does

- `import_relative 'billing/invoice'` raises `Carton::ImportError`: the file is in the billing Carton's Interior, so only `billing` can be imported.
- Each Carton loads once per process. Every later import returns the same value, from the app or from another Carton.
- `import 'billing'` searches `$LOAD_PATH` like `require`, so gems and path gems import by name.

## Next steps

- [Cartons](/guides/cartons/): what belongs to a Carton, and how Zeitwerk fits.
- [Exporting](/guides/exporting/) and [Importing](/guides/importing/): the whole language.
- [Bundler](/guides/bundler/): give a Carton its own gems.
- The [examples](https://github.com/dtcristo/carton/tree/main/examples) in the repository, starting with [minimal](https://github.com/dtcristo/carton/tree/main/examples/minimal).
