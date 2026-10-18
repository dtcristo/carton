# Minimal example

In plain Ruby, any file can `require` any other file and reach any constant,
so internal code turns into public API by accident. A Carton has one way in,
its Entrypoint, and importers get only what it exports. This is the smallest
example of that boundary, with no gems or Bundler, and it covers every idea in
the [quick start](../../README.md#quick-start):

```
main.rb              # imports billing and math
billing.rb           # the billing Carton's Entrypoint: export_default Billing
billing/invoice.rb   # inside the billing Carton
billing/tax.rb       # inside too; imports math
math.rb              # a Carton of one file, with Named Exports
```

- `billing.rb` loads its own files with `require_relative`, all inside the
  billing Carton's one Box, and exports `Billing` with `export_default`.
- `Billing::Tax` is hidden with `private_constant`.
- `billing/tax.rb` imports `math`, another Carton, across a boundary. The app
  imports `math` too and gets the same Carton.
- `math.rb` uses `export` for a method and a constant, so importing it returns
  a `Carton::Exports` namespace.
- `main.rb` shows that `import_relative 'billing/invoice'` raises
  `Carton::ImportError`: only a Carton's Entrypoint can be imported.

## Run

```sh
RUBY_BOX=1 ruby examples/minimal/main.rb
```

## Types

`sig/billing.rbs` declares the billing Carton's types, and `math.rb` annotates
`percent` with an rbs-inline `#:` comment. `carton rbs main.rb` generated
`sig/generated/carton.rbs`, which types each import, and Steep checks
`main.rb` against both:

```sh
cd examples/minimal
bundle exec carton rbs main.rb
bundle exec steep check
```

`ruby ../../exe/carton check main.rb` reports the deliberate import of
`billing/invoice`.
