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

Run it with:

```sh
RUBY_BOX=1 ruby examples/monorepo/main.rb
```

A package can leave the monorepo as a published gem without changes, since it
already is one.

## Undeclared imports

Carton does not enforce the gemspec yet. A package imported from a bundled app
sees the app's whole lockfile, as `Bundler.setup` gives the Main Box, so
`import 'shipping'` inside `billing` would work even though `billing.gemspec`
does not declare it. Reporting that from a static `carton check` is proposed
in [dtcristo/carton#32](https://github.com/dtcristo/carton/issues/32).
