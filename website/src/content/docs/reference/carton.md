---
title: Carton
description: Reference for the Carton module, setup_bundle, and VERSION.
sidebar:
  order: 2
---

## `Carton.setup_bundle`

```ruby
def self.setup_bundle: (*Symbol groups, ?gemfile: String?) -> untyped
```

Sets up a bundle in the current Box, like `Bundler.setup`. In a Carton's Entrypoint, it gives that Carton a Carton Bundle of its own; in the app, it sets up the app's bundle.

- `groups` limits setup to those groups, such as `Carton.setup_bundle(:default, :test)`. With none, every group is set up.
- `gemfile:` chooses the Gemfile, relative to the calling file. Without it, Carton searches upward from the calling file for `gems.rb` or `Gemfile`.
- `ENV` is restored when setup finishes, so the bundle never leaks into the importer's subprocesses.
- Bundler errors raise instead of exiting the process.

Raises [`Carton::GemfileNotFound`](/reference/errors/) when there is no Gemfile.

```ruby
# reports/lib/reports.rb
Carton.setup_bundle # reports/Gemfile, in this Carton's Box only
require 'bigdecimal'
```

## `Carton::VERSION`

The installed Carton version, as a String.
