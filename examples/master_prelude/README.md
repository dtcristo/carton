# Master prelude example (optional, unsupported hack)

**You do not need this.** It is only worth it if you want the same monkey
patches, such as all of Active Support's core extensions, in every Carton
without each Carton loading them. It relies on Ruby behavior that Ruby's docs
say does not happen, so it may break in a future Ruby.

## What it does

A new Box copies Ruby's internal Master Box. Ruby documents Master as a copy
source in which "no code runs", but on Ruby 4.0.7 code can be required there
anyway, and every Box created afterwards inherits it:

```ruby
master = Ruby::Box.master
master.load_path.unshift(*gem_paths)
master.require('prelude.rb')      # require 'active_support/core_ext'

Pricing = import_relative 'cartons/pricing' # its Box already has blank?, 14.days
```

`main.rb` does this before the first import. `cartons/pricing.rb` and
`cartons/reports.rb` then use `presence`, `14.days`, `blank?`, and
`to_sentence` without requiring Active Support. The Main Box is unchanged.

The alternative is to `require` the patches in every Carton that needs them.
That is supported and keeps each Box fully isolated, but it loads them once per
Box: about 830ms per Box for all of `active_support/core_ext` in a Rails
bundle, against a single load here.

## Caveats

- **Unsupported.** It depends on `Ruby::Box.master` accepting code. A future
  Ruby could freeze Master or reject this.
- **Shared state.** Objects and module state created by the prelude are the
  same objects in every Carton. Keep the prelude to monkey patches and
  stateless helpers. A Carton reopening a prelude class or adding its own
  patches still only changes its own Box.
- **Leaked load path.** Prelude methods run in Master even when a Carton calls
  them, so lazy `require`s inside them (I18n loads its backend on first use)
  search Master's load path. The gem paths therefore stay on Master's load
  path, and every Carton Box inherits them.
- **Order.** Only Boxes created after the prelude get it, so load it before
  the first import.

[docs/internals/how-boxes-work.md](../../docs/internals/how-boxes-work.md#the-master-box-on-ruby-407)
has the details and probes.

## Run

```sh
RUBY_BOX=1 ruby examples/master_prelude/main.rb
```
