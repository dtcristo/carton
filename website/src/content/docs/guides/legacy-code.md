---
title: Legacy Ruby and gems
description: Load existing Ruby through a distinct Entrypoint that requires it and explicitly exports the value importers need.
sidebar:
  order: 4
---

Every imported Entrypoint must call `export` exactly once. To give existing Ruby a Carton boundary without changing it, write a distinct adapter Entrypoint that requires the legacy code, then explicitly exports the value Importers need.

## Legacy files

Keep the original file as ordinary Ruby:

```ruby
# legacy.rb: ordinary Ruby, loaded with require_relative
PREFIX = 'INV'

def label(number) = format('%s-%04d', PREFIX, number)
```

The adapter owns the Carton boundary and chooses its Export:

```ruby
# legacy_adapter.rb: the imported Entrypoint
require_relative 'legacy' # loads inside this Carton Box

export prefix: PREFIX, label: method(:label)
```

```ruby
# main.rb
require 'carton'

legacy = import_relative 'legacy_adapter'
legacy => { label:, prefix: }
label.call(42) # => "INV-0042"
prefix         # => "INV"
defined?(PREFIX) # => nil
```

The import returns a plain Hash containing exactly the values the adapter exports. The captured `Method` is a value the app calls explicitly. The required file's definitions stay in the adapter's Box.

Keep the adapter distinct from the legacy file and outside any other Carton's Interior, so it can be imported. Calling `export` in a required file remains inert and cannot satisfy the adapter's requirement. A plain `require` of the legacy file still works without an adapter or an Export.

## Legacy gems

Require a legacy gem inside a Carton, then export the gem's module or a smaller value. When the Carton needs its own gem versions, set up its own [Carton Bundle](/guides/bundler/#a-cartons-own-bundle) before requiring the gem:

```ruby
# decimal_adapter.rb: the imported Entrypoint
Carton.setup_bundle # this adapter's own Gemfile
require 'bigdecimal' # loads the legacy gem in this Carton Box

export BigDecimal
```

```ruby
# main.rb
require 'carton'

Decimal = import_relative 'decimal_adapter'
Decimal::VERSION
```

Without Bundler, use ordinary RubyGems activation inside the adapter when a particular version is needed. The gem itself needs no Carton API. Importing its unmodified Entrypoint directly would raise `Carton::ExportError` if it never calls `export`.

See [Exports](/guides/examples/exports/) for the runnable file adapter and [Bundler](/guides/examples/bundler/) for a Carton that requires bigdecimal and exports its version.
