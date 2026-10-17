# Monorepo example

An app split into packages, where each package is a gem and Bundler is the
manifest ([dtcristo/carton#32](https://github.com/dtcristo/carton/issues/32)):

- Each package under `packages/` is a path gem. Its gemspec names it and lists
  the packages and gems it depends on.
- One `Gemfile` and `Gemfile.lock` cover the whole monorepo and pin every
  third-party version.
- `import 'billing'` loads a package by gem name in its own Box. Only its
  `export_default` value crosses back.
- `billing` imports `pricing`, its declared dependency. Imports are cached per
  process, so `billing` and the app share one `pricing` Carton.
- `Pricing::Rounding` is hidden with `private_constant`.
- `bigdecimal` loads inside `pricing`'s Box at the locked version, not in the
  Main Box.

```
Gemfile                    # carton, the three packages, bigdecimal 4.1.1
main.rb                    # Carton.setup_bundle, then import each package
packages/
  pricing/
    pricing.gemspec        # depends on bigdecimal
    lib/pricing.rb         # Entrypoint: export_default Pricing
  billing/
    billing.gemspec        # depends on pricing
    lib/billing.rb         # Pricing = import 'pricing'
  shipping/
    shipping.gemspec       # no dependencies
    lib/shipping.rb
```

A package can leave the monorepo as a published gem without changes, since it
already is one.

## Undeclared imports

A package imported from a bundled app sees the app's whole lockfile, as
`Bundler.setup` gives the Main Box, so `import 'shipping'` inside `billing`
would work at runtime even though `billing.gemspec` does not declare it.
`carton check` reports it:

```sh
cd examples/monorepo
bundle exec ruby ../../exe/carton check main.rb
# packages/billing/lib/billing.rb:7: error: import 'shipping' loads the
# shipping gem, which billing's gemspec does not declare: add
# spec.add_dependency 'shipping'
```

Enforcing it at runtime too is proposed in
[dtcristo/carton#38](https://github.com/dtcristo/carton/issues/38) as strict
gem Cartons.

## Run

```sh
RUBY_BOX=1 ruby examples/monorepo/main.rb
```
