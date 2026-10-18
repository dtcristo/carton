# Export values example

An Import returns the Entrypoint's Export, or a Namespace for a Bare Carton. [minimal](../minimal/README.md) exports a module; this example covers a Hash, a callable, and an existing file with no `export`. It needs no gems or Bundler.

| File | Import returns | How the app uses it |
| --- | --- | --- |
| `settings.rb` | A plain Hash from `export currency: 'USD'` | Ruby pattern matching extracts `currency` |
| `formatter.rb` | A Proc | `money.call(4_200)` formats cents |
| `legacy.rb` | A `Carton::Namespace`, since the file has no `export` | `Legacy.label(42)`, `Legacy::PREFIX`, or pattern matching |

The legacy file is ordinary Ruby with a constant and a top-level method, a Helper. It runs in a Carton Box, so `PREFIX` does not become a constant in Main. `Legacy` exposes the Entrypoint's constants and Helpers; the Carton Box stays private. Pattern matching captures the Helper as a Method, which the Importer invokes with `.call`. New Cartons should export a deliberate value; Bare Cartons let existing code load unchanged.

Every Shared Import returns the same Export or Namespace. If you export a mutable Hash, every Importer gets that same Hash; freeze it if it is intended to be read-only. A Bare Carton's Namespace is the one case where Carton supplies a container for discovered members.

## Run

From the repository root:

```sh
RUBY_BOX=1 ruby examples/exports/main.rb
```

```text
INV-0042: USD 42.00
Captured Helper: INV-0007
Legacy prefix: INV
PREFIX defined in Main: false
```

`bundle exec rake example:exports` runs the same program, and `carton check` can check it without running it.
