# Rails in Main example

Domain logic inside a Rails app can call any model, helper, or core
extension, so its boundary wears away one convenient call at a time. This is
the smallest change to an existing Rails app that stops that. Rails and its
controllers stay where they are, and domain logic moves into a Carton that
cannot see Rails or the app's constants. The app reaches it only through its
export:

- Rails, its controllers, and its Zeitwerk autoloader run in the Main Box.
- `components/billing` is a path gem and a Carton. It runs in its own Box, with
  its own Zeitwerk loader and the `zeitwerk` version this app's lockfile pins.
- `config/initializers/billing.rb` imports it once with
  `Billing = import 'billing'`; only its `export_default` value crosses back.
- `Billing::TaxPolicy` is hidden with `private_constant`, and Rails' core
  extensions (`blank?`, ...) are not visible inside the Carton's Box.

```
Gemfile                          # rails gems + billing (path, require: false)
config/application.rb            # bundler/setup, require 'carton', Rails config
config/environment.rb
config/routes.rb
config/initializers/billing.rb   # Billing = import 'billing'
app/controllers/invoices_controller.rb
components/billing/
  billing.gemspec                # depends on zeitwerk
  lib/billing.rb                 # Entrypoint: Zeitwerk loader, export_default Billing
  lib/billing/invoice.rb         # eager loaded inside the Carton's Box
main.rb                          # boots the app and sends GET /invoices/42 via Rack
```

## Why controllers and models stay in Main

A Carton's Box is copied from Ruby's clean Master Box, so it does not see Rails.
Defining a controller or model inside a Carton would need Rails loaded again
in that Box. Rails' core extensions are Box-local monkey patches, and Rails
resolves controllers and associations by constant name in the Main Box.
Loading Rails into the Root Box first does not help on Ruby 4.0.7: new Boxes do
not inherit it. So Rails layers stay in Main and Cartons hold domain logic.
A Carton may still be handed Main objects, such as records, and call their
methods.

## Development

Each Carton loads once per process, and Carton never reloads an imported
Carton, so restart the process to pick up a change. A file watcher can do it
for you. This loop needs only Ruby. It starts the app, checks every `.rb` and
`.yml` file twice a second, and restarts the app when one changes:

```sh
cd examples/rails_in_main
ruby -e '
  snapshot = -> { Dir["**/*.{rb,yml}"].to_h { [it, File.mtime(it)] } }
  loop do
    seen = snapshot.()
    pid = spawn({ "RUBY_BOX" => "1" }, *ARGV)
    sleep 0.5 while snapshot.() == seen
    Process.kill(:TERM, pid)
    Process.wait(pid)
  end
' ruby main.rb
```

`main.rb` sends one request and exits, so here each change runs it again.
For a real app, put the server command in place of `ruby main.rb`. A
watcher such as [watchexec](https://github.com/watchexec/watchexec) with
`--restart` does the same job.

Zeitwerk can reload code inside a Carton's Box, but importers keep the
classes and objects they already hold, and this Carton's
`Zeitwerk::Loader.for_gem` loader cannot reload at all.
[examples/zeitwerk](../zeitwerk/README.md#reloading) covers when reloading
works and its limits.

## Run

```sh
RUBY_BOX=1 ruby examples/rails_in_main/main.rb
```
