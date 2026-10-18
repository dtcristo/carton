# Minimal example

This is the smallest working app with Carton boundaries, with no gems or Bundler. Start here for the module exports and imports in the [quick start](../../README.md#quick-start), then see [exports](../exports/README.md) for Hashes, callables, and Bare Cartons.

```
main.rb              # imports billing and math
billing.rb           # the billing Carton's Entrypoint: export Billing
billing/invoice.rb   # inside the billing Carton
billing/tax.rb       # inside too; imports math
math.rb              # a Carton of one file: export MathTools
violations.rb        # deliberately invalid code for carton check
```

- `billing.rb` loads its own files with `require_relative`, all inside the billing Carton's one Box, and exports `Billing`.
- `Billing::Tax` is hidden with `private_constant`.
- `billing/tax.rb` imports `math`, another Carton, across a boundary. The app imports `math` too and gets the same Carton.
- `main.rb` uses only the public API. `violations.rb` tries to reach the private `Billing::Tax` and import `billing/invoice` directly; both violate the boundary.

## Run

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
```

## Types

`sig/billing.rbs` and `sig/math_tools.rbs` declare each Carton's types, as a gem's RBS would. `carton rbs main.rb` generated `sig/generated/carton.rbs`, which types each import, and Steep checks `main.rb` against both:

```sh
cd examples/minimal
bundle exec carton rbs main.rb
bundle exec steep check
```

## Checks

From the repository root, the working app passes static checks, while the separate diagnostic example reports two errors:

```sh
bundle exec carton check examples/minimal/main.rb
bundle exec carton check examples/minimal/violations.rb # exits 1, as intended
```

The second command reports the private constant access and the import of a file inside the billing Carton without running either. Running `violations.rb` as Ruby instead stops at its first `NameError`.
