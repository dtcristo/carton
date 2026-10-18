# Export values example

`import` returns the value an Entrypoint exports. [minimal](../minimal/README.md) exports a module; this example covers a Hash, a callable, and an existing file with no `export`. It needs no gems or Bundler.

| File | Import returns | How the app uses it |
| --- | --- | --- |
| `settings.rb` | A plain Hash from `export currency: 'USD'` | Ruby pattern matching extracts `currency` |
| `formatter.rb` | A Proc | `money.call(4_200)` formats cents |
| `legacy.rb` | A `Carton::Namespace`, since the file has no `export` | `Legacy.label(42)`, `Legacy::PREFIX`, or pattern matching |

The legacy file is ordinary Ruby with a constant and a top-level helper. It runs in a Box, so `PREFIX` does not become a constant in Main. `Legacy` exposes the Entrypoint's constants and helpers; the Box stays private. Pattern matching captures the helper as a Method, which the caller invokes with `.call`. New Cartons should export a deliberate value; Bare Cartons let existing code load unchanged.

Exports are shared across imports. If you export a mutable Hash, every importer gets that same Hash; freeze it if it is intended to be read-only. A Bare Carton's Namespace is the one case where Carton supplies a container for discovered members.

## Run

From the repository root:

```sh
RUBY_BOX=1 ruby examples/exports/main.rb
```

```text
INV-0042: USD 42.00
Captured helper: INV-0007
Legacy prefix: INV
PREFIX defined in Main: false
```

`bundle exec rake example:exports` runs the same program, and `carton check` can check it without running it.
