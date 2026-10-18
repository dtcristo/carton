# Rails in Main example

This is the recommended way to use Carton with Rails today: Rails, its controllers, models, and tooling stay where Rails expects them, and selected plain-Ruby domains run as Cartons.

Domain logic inside a Rails app can call any model, helper, or core extension, so its boundary wears away one convenient call at a time. This is the smallest change to an existing Rails app that stops that. Rails and its controllers stay where they are, and domain logic moves into a Carton that cannot see Rails or the app's constants. The app reaches it only through its export:

- Rails, its controllers, and its Zeitwerk autoloader run in the Main Box.
- `components/billing` is a path gem and a Carton. It runs in its own Box, with its own Zeitwerk loader and the `zeitwerk` version this app's lockfile pins.
- `config/initializers/billing.rb` imports it once with `Billing = import 'billing'`; only its `export` value crosses back.
- `Billing::TaxPolicy` is hidden with `private_constant`, and Rails' core extensions (`blank?`, ...) are not visible inside the Carton Box.

```
Gemfile                          # rails gems + billing (path, require: false)
config/application.rb            # bundler/setup, require 'carton', Rails config
config/environment.rb
config/routes.rb
config/initializers/billing.rb   # Billing = import 'billing'
app/controllers/invoices_controller.rb
components/billing/
  billing.gemspec                # depends on carton and zeitwerk
  lib/billing.rb                 # Entrypoint: Zeitwerk loader, export Billing
  lib/billing/invoice.rb         # eager loaded inside the Carton Box
main.rb                          # boots the app and sends GET /invoices/42 via Rack
```

## Why controllers and models stay in Main

A Carton's Box starts from Ruby's clean Master Box, so the app's `ApplicationRecord`, `ApplicationController`, and Rails constants are not available there by name. Sharing framework classes explicitly is possible, as [rails_in_cartons](../rails_in_cartons/README.md) demonstrates, but Rails also needs to resolve controller and association names in its own Box. Keeping those layers in Main avoids that registration work and preserves Rails tooling. Plain-Ruby domains run as Cartons and may receive host objects, such as records, through [dependency injection](../dependency_injection/README.md).

## Development

`main.rb` sends one request and exits. Rerun it after editing; restart a long-running host to pick up changed Cartons. See [Editing code](../README.md#editing-code) for restart and reloading guidance.

Zeitwerk can reload code inside a Carton Box, but Importers keep the classes and objects they already hold, and this Carton's `Zeitwerk::Loader.for_gem` loader cannot reload at all. [examples/zeitwerk](../zeitwerk/README.md#reloading) covers when reloading works and its limits.

## Run

From the repository root:

```sh
bundle exec rake example:rails_in_main
```

After setup:

```sh
RUBY_BOX=1 ruby examples/rails_in_main/main.rb
```
