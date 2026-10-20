---
title: Rails
description: Keep Rails in the Main Box and move plain-Ruby domains into Cartons, and mount Engines whose application code lives in Cartons.
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
require_relative 'boot'
require 'carton' # after Bundler; adds import to the Main Box
require 'rails'
require 'active_record/railtie'
require 'active_job/railtie'
require 'action_controller/railtie'
require 'action_view/railtie'
```

```ruby
# config/initializers/billing.rb
module Shop
  Billing = import 'billing' # app namespace avoids Rake's top-level import
end
```

The billing gem is a Gem Carton, so it gets the gems its gemspec declares at the versions the app's lockfile pins:

```ruby
# components/billing/billing.gemspec
spec.add_dependency 'carton'
spec.add_dependency 'zeitwerk' # loaded in billing's Box
```

Its Entrypoint runs its own Zeitwerk loader, separate from Rails', and hides what it keeps private:

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

Controllers and models call `Shop::Billing` like any other constant. Keep imports inside a module or class because Rake also defines a top-level `import`.

- **Core extensions stay out.** Active Support's patches, such as `blank?`, are monkey patches in the Main Box, so they are not visible inside a Carton. A Carton that wants them declares `activesupport` in its gemspec and requires only what it needs, such as `require 'active_support/core_ext/object/blank'`.
- **Rails' loader stays out.** If a directory Rails autoloads contains a Carton, `ignore` the Carton's Entrypoint and directory there; see [Zeitwerk](/guides/cartons/#zeitwerk).
- **Records come in as arguments.** A Carton cannot see `ApplicationRecord` or the app's models by name. Pass records, repositories, or other services in; see [Passing application services](/guides/sharing-classes/#passing-application-services).
- **Restart on change.** Each Carton loads once per process, so a running server restarts to pick up a changed Carton. A `for_gem` loader cannot reload at all.

The [rails_in_main example](https://github.com/dtcristo/carton/tree/main/examples/rails_in_main) has conventional Rails boot files, `config.ru`, `bin/rails`, migrations, Active Record models, HTML/JSON controllers, and an Active Job. Its model passes values across the boundary:

```ruby title="app/models/invoice.rb"
class Invoice < ApplicationRecord
  def quote
    Shop::Billing::Invoice.new(id: id, subtotal_cents: subtotal_cents)
  end
end
```

The database and host model stay in Main. Billing needs neither Rails nor a reference to the application's model class. Rails renders its returned values through normal view helpers or JSON; the app's job can serialize a host record through GlobalID.

After installing the example's bundle:

```sh
cd examples/rails_in_main
RUBY_BOX=1 bin/rails db:prepare
RUBY_BOX=1 bin/rails runner 'puts Invoice.create!(subtotal_cents: 4200).id'
RUBY_BOX=1 bin/rails test
RUBY_BOX=1 bin/rails server -b 127.0.0.1
```

Visit `/invoices/<id>` or `/invoices/<id>.json`. The example tests requests, validation, job serialization, private constants, and Box provenance with lazy and eager loading. It also tests routes, runner, migration reruns, Zeitwerk checks, generator dry runs, and a real Puma HTTP response. Its CLI is Rails' ordinary command loader in Main.

The example selects its Railties explicitly. Full `rails/all` initialization on Ruby 4.0.7 with Boxes enabled can hit upstream autoload and isolated-Proc bugs through Action Cable and mail dependencies. The example READMEs record those tested limits. Jobs use an inline adapter, and running apps restart after changes to Cartons.

## Engines in Cartons

The [Rails-in-Cartons example](https://github.com/dtcristo/carton/tree/main/examples/rails_in_cartons) takes a different approach. Rails loads in a shared framework Carton. Customers and Orders are isolated Rails Engines, each with namespaced models, controllers, jobs, routes, views, and migrations. A shop Carton mounts both Engines and exports its Rack application.

Engine namespace isolation alone does not give Box isolation. Each Engine Carton uses its own Zeitwerk loader for Ruby application files and configures Rails' main loader to ignore those directories. Rails still manages Engine discovery, route files, mounts, views, and migration tasks. The framework explicitly binds the exported namespace objects so Rails can resolve qualified class names.

The example verifies JSON and HTML requests, validation errors, cross-engine associations, GlobalID jobs, and application method provenance under both lazy and eager loading. Shared framework classes and registries remain shared Ruby objects; [reopening them](/guides/sharing-classes/) affects every holder.

## Commands and development

After installing the example's bundle, run its explicit CLI bridge from the shop app:

```sh
cd examples/rails_in_cartons/components/shop
RUBY_BOX=1 bin/rails db:prepare
RUBY_BOX=1 bin/rails routes
RUBY_BOX=1 bin/rails test
RUBY_BOX=1 bin/rails server -b 127.0.0.1
```

The example README lists the verified commands and database configuration. This `bin/rails` enters the framework Carton before loading Rails commands; it does not require a second Rails implementation in Main. Stock Rails/Rake commands, interactive console, and arbitrary third-party Engines are not covered by this example's contract.

Restart after edits. The separate reloading spike remains unsupported and is never loaded by the ordinary app. Active Support extensions used by domain code must be explicitly required in that Carton. Mailers and other unverified Rails subsystems have no compatibility claim; the README records the Ruby 4.0.7 limitation found during mailer investigation.
