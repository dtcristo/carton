---
title: Exporting
description: Export one value from a Carton's Entrypoint, hide private constants, and export a few values as a Hash.
sidebar:
  order: 2
---

Every imported Entrypoint must call `export` exactly once. If it finishes loading without an Export, the import raises `Carton::ExportError`. Importing returns the exported value itself. Most Cartons have one main class or module, so they export it, as `require` would leave a constant behind:

```ruby
# user.rb
class User
  def initialize(name) = @name = name
end

export User # Importers receive User itself
```

```ruby
# main.rb
User = import_relative 'user'
User.new('Alice')
```

- The value may be anything, including a Hash, `nil`, or `false`.
- Call `export` once per Entrypoint; a second call raises `Carton::ExportError`. Put other names inside the exported value instead, such as `User::VERSION`.
- A Symbol raises `Carton::ExportError`, so `export def add` cannot export `:add` by mistake. To export methods, define them on a module and export the module.
- Bind the import to its own name, `User = import 'user'`. Rename only to resolve a clash between Cartons: `Module#name`, `inspect`, and backtraces keep the original name.

## A root module with private constants

Export the root module and hide everything else with Ruby's own `private_constant`, which holds across Boxes:

```ruby
# lib/pricing.rb
module Pricing
  class Calculator
  end

  module Internal
  end
  private_constant :Internal # stays inside the Carton
end

export Pricing
```

```ruby
# main.rb
Pricing = import 'pricing'
Pricing::Calculator # public
Pricing::Internal   # NameError: private constant Pricing::Internal referenced
```

## A few values

Keywords export a plain Hash, for values that need no module of their own:

```ruby
# info.rb
export version: '1.0', built_on: 'ci'
```

```ruby
# main.rb
Info = import_relative 'info'
Info[:version] # => "1.0"
import_relative('info') => { version: }
```

## Exports under plain `require`

Only the imported Entrypoint's `export` counts. In any other file, including one loaded with plain `require` by an app or by another Carton, `export` checks its argument, returns it, and does nothing else.

An `export` in a required file does not satisfy the Entrypoint's requirement.

A gem can add `export MyGem` and keep working under plain `require 'my_gem'`: declare `carton` as a runtime dependency and `require 'carton'` at the top of its Entrypoint.
