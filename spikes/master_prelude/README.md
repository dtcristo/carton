# Master prelude spike

A Carton that wants Active Support's core extensions has to load them in its own Box, which takes about 830ms per Box in a Rails bundle. This hack loads them once, into Ruby's internal Master Box, and every Carton created after that starts with them.

**You do not need this.** Requiring the patches in each Carton works and is supported. This relies on Ruby behavior that Ruby's docs say does not happen, so it may break in a future Ruby.

## Question and status

Can an application pay for Active Support core extensions once by changing Ruby's Box copy source? Yes on the tested Ruby 4.0.7, but this is unsupported and violates the clean-Master architecture. It is retained as research and a comparison for [Shared Gems](../shared_gems/results.md), not an integration direction. The supported alternative is to require the needed extensions in each Carton.

## What it does

A new Box copies Ruby's internal Master Box. Ruby documents Master as a copy source in which "no code runs", but on Ruby 4.0.7 code can be required there anyway, and every Box created afterwards inherits it:

```ruby
master = Ruby::Box.master
master.load_path.unshift(*gem_paths)
master.require('prelude.rb')      # require 'active_support/core_ext'

Pricing = import_relative 'cartons/pricing' # its Box already has blank?, 14.days
```

`main.rb` does this before the first import. `cartons/pricing.rb` and `cartons/reports.rb` then use `presence`, `14.days`, `blank?`, and `to_sentence` without requiring Active Support.

The prelude is not confined to later Boxes. Main and any Box that already exists may see its patches too, depending on whether Ruby has already copied each builtin class's state for that Box, which ordinary method calls can trigger. On Ruby 4.0.7 this spike's Main does not see `''.blank?` but does see `1.day`; `main.rb` prints both.

The alternative is to `require` the patches in every Carton that needs them. That is supported and keeps each Box fully isolated, but it loads them once per Box: about 830ms per Box for all of `active_support/core_ext` in a Rails bundle, against a single load here.

## Caveats

- **Unsupported.** It depends on `Ruby::Box.master` accepting code. A future Ruby could freeze Master or reject this.
- **Leaks into Main.** Patches can reach Main and existing Boxes, as above, and which ones do depends on Ruby's copy-on-write state.
- **Shared state.** Objects and module state created by the prelude are the same objects in every Carton. Keep the prelude to monkey patches and stateless helpers. A Carton's own patches to builtins such as `String` stay in its Box, but reopening a class the prelude defined (say `ActiveSupport::Duration`) changes it in every Carton.
- **Leaked load path.** Prelude methods run in Master even when a Carton calls them, so lazy `require`s inside them (I18n loads its backend on first use) search Master's load path. The gem paths therefore stay on Master's load path, and every Carton Box inherits them.
- **Order.** Only Boxes created after the prelude get it, so load it before the first import.

[docs/internals/how-boxes-work.md](../../docs/internals/how-boxes-work.md#the-master-box-on-ruby-407) has the details and probes.

## Run

From the repository root:

```sh
bundle exec rake spike:master_prelude
```

After setup:

```sh
RUBY_BOX=1 ruby spikes/master_prelude/main.rb
```

## Verified result and checks

The demo asserts `presence`, `14.days`, `blank?` and `to_sentence` from two Cartons without local Active Support requires. It prints the one-time prelude and import times, plus Main's visibility of the patches. Those timings describe the current machine; the historical 830 ms comparison above is a separate measurement. There is no transactional rollback or promise that existing Boxes stay unaffected.

`bundle exec rake spikes` runs this demo and the Rails reloading regression in separate processes. CI runs that task separately from the ordinary example suite. Both this spike's code and the reloading spike remain covered by RuboCop.
