# Monorepo example

When a large app splits its code into packages by directory alone, nothing stops one package from calling another's internals, and the dependency graph lives only in people's heads. Here each package is a Carton: a gem that declares its dependencies and runs in its own Box, and Bundler is the manifest ([dtcristo/carton#32](https://github.com/dtcristo/carton/issues/32)):

- Each Carton under `cartons/` is a path gem. Its gemspec names it and declares Carton and the other runtime gems it uses. Its Entrypoint requires Carton so `export` is defined for ordinary `require` consumers too.
- One `Gemfile` and `Gemfile.lock` cover the whole monorepo and pin every third-party version.
- `import 'billing'` loads a Carton by gem name in its own Box. Only its Export crosses back.
- `billing` imports `pricing`, its declared dependency. Each Carton loads once per process, so `billing` and the app share one `pricing` Carton.
- `Pricing::Rounding` is hidden with `private_constant`.
- `bigdecimal` loads inside `pricing`'s Box at the locked version, not in the Main Box.

```
Gemfile                    # carton, the three Cartons, bigdecimal 4.1.1
main.rb                    # Carton.setup_bundle, then import each Carton
cartons/
  pricing/
    pricing.gemspec        # depends on bigdecimal
    lib/pricing.rb         # Entrypoint: export Pricing
  billing/
    billing.gemspec        # depends on pricing
    lib/billing.rb         # Pricing = import 'pricing'
  shipping/
    shipping.gemspec       # only depends on carton
    lib/shipping.rb
```

A Carton can leave the monorepo as a published gem without changes, since it already is one.

## Undeclared imports

A Gem Carton imported by a bundled Importer sees the Importer's whole lockfile, as `Bundler.setup` gives the Main Box. The checked-in example declares every runtime gem and passes `carton check`. To see an Undeclared Gem reported, temporarily add `Shipping = import 'shipping'` inside the `Billing` module in `cartons/billing/lib/billing.rb`, then run:

```sh
cd examples/monorepo
bundle exec ruby ../../carton-tools/exe/carton check main.rb
# cartons/billing/lib/billing.rb:<line>: error: import 'shipping' loads the
# shipping gem, which billing's gemspec does not declare: add
# spec.add_dependency 'shipping'
```

That Import would work at runtime even though `billing.gemspec` does not declare it. Remove the temporary Import after checking it. Enforcing declarations at runtime too is proposed in [dtcristo/carton#38](https://github.com/dtcristo/carton/issues/38) as strict Gem Cartons.

## Tests

`test/` shows both ways to test a Carton. Both run under the monorepo's bundle, which locks `minitest` in its `test` group.

- `test/pricing_test.rb` is a unit test. It loads `pricing` with plain `require`, so there is no Box or boundary, and tests the private `Pricing::Rounding` through `Pricing.const_get(:Rounding)`. It runs with or without `RUBY_BOX=1`.
- `test/app_test.rb` is an integration test. It imports `billing` and `pricing` as `main.rb` does, tests their exports, and checks that `Pricing::Rounding` and `bigdecimal` stay hidden.

Each file runs in its own process, since the unit test's `require` would load a second copy of `pricing` beside the imported one. `rake example:monorepo` runs `main.rb` and then each test file.

```sh
ruby examples/monorepo/test/pricing_test.rb
RUBY_BOX=1 ruby examples/monorepo/test/app_test.rb
```

## Run

From the repository root:

```sh
bundle exec rake example:monorepo
```

After setup, run the app directly:

```sh
RUBY_BOX=1 ruby examples/monorepo/main.rb
```
