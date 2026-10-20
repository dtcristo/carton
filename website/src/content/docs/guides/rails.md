---
title: Rails
description: Keep Rails in the Main Box and move plain-Ruby domains into Cartons, and what running Rails inside Cartons involves.
sidebar:
  order: 9
---

Domain logic inside a Rails app can call any model, helper, or core extension, so its boundary wears away one convenient call at a time. Carton's recommended setup today keeps Rails, its controllers, models, and tooling in the Main Box, and moves plain-Ruby domains into Cartons that cannot see Rails or the app's constants.

## Rails in the Main Box

Make each domain a path gem, and keep `Bundler.require` from loading it into the Main Box:

```ruby title="Gemfile"
gem 'carton'
gem 'rails'

gem 'billing', path: 'components/billing', require: false # imported, not required
```

Require Carton after Bundler, then import each domain once at boot:

```ruby
# config/application.rb
require 'bundler/setup'
require 'carton'
require 'rails/all'
```

```ruby
# config/initializers/billing.rb
Billing = import 'billing' # loads in its own Box; only the export crosses
```

The billing gem is a Gem Carton, so it gets the gems its gemspec declares at the versions the app's lockfile pins. Its Entrypoint runs its own Zeitwerk loader, separate from Rails', and hides what it keeps private:

```ruby
# components/billing/lib/billing.rb
require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem # this Box's own Zeitwerk
loader.setup

module Billing
  module TaxPolicy
  end
  private_constant :TaxPolicy # NameError from the app
end

loader.eager_load # fail at boot, as Rails does in production

export Billing
```

Controllers and models call `Billing` like any other constant.

- **Core extensions stay out.** Active Support's patches, such as `blank?`, are monkey patches in the Main Box, so they are not visible inside a Carton. A Carton that wants them loads Active Support itself.
- **Rails' loader stays out.** If a directory Rails autoloads contains a Carton, `ignore` the Carton's Entrypoint and directory there; see [Zeitwerk](/guides/cartons/#zeitwerk).
- **Records come in as arguments.** A Carton cannot see `ApplicationRecord` or the app's models by name. Pass records, repositories, or other services in; see [Passing application services](/guides/sharing-classes/#passing-application-services).
- **Restart on change.** Each Carton loads once per process, so a running server restarts to pick up a changed Carton.

The [rails_in_main example](https://github.com/dtcristo/carton/tree/main/examples/rails_in_main) runs this setup.

## Rails inside Cartons

Rails can also run inside Cartons, with one Carton for the framework and one per domain, each owning its models, controllers, and tables. This is experimental: domains share the framework's classes, must register their constants with it explicitly, and get no supported reloading or Rails CLI. Do not freeze shared Active Record classes; see [Sharing classes](/guides/sharing-classes/#freeze-plain-ruby-exports).

The [rails_in_cartons example](https://github.com/dtcristo/carton/tree/main/examples/rails_in_cartons) shows how it works and where it stops.
