# Spikes

These directories hold research, unsupported behavior and private-runtime experiments. Their READMEs record the question, verified results, limits and how to reproduce them. Successful assertions establish only the behavior each experiment exercises.

| Spike | Question | Result and status |
| --- | --- | --- |
| [Master prelude](master_prelude/README.md) | Can loading Active Support into Master make new Boxes inherit its patches? | Yes on Ruby 4.0.7, but it changes the process-wide copy source and can affect existing Boxes. Unsupported. |
| [Rails reloading](rails_reloading/README.md) | Can domain Cartons reload while an initialized Rails app and database remain? | Two serial edits work with explicit reference replacement and private cache inspection. No supported reload API. Uses the Rails-in-Cartons example as a read-only fixture. |
| [Shared Gems](shared_gems/README.md) | Can public Ruby APIs reuse initialized gem definitions across independent Boxes? | Selected Active Support and Rails-domain checks work; ordinary gem loading and activation remain incompatible. |

The [ordinary examples](https://carton.dtcristo.com/guides/examples/) demonstrate Carton use. Both Rails examples remain there: Rails in Main is the recommended setup today, and Rails in Cartons is an experimental integration direction. These spikes add no supported runtime API.

## Run

From the repository root, install the development bundle, then choose a regression spike:

```sh
bundle install
bundle exec rake spike:master_prelude
bundle exec rake spike:rails_reloading
bundle exec rake spikes
```

The tasks install their required bundles, enable Boxes, and run in fresh child processes. Rails reloading edits a temporary copy of its fixture and removes it on exit. The Master control runs in its own process so its mutations end with that process.

`bundle exec rake` runs the ordinary test, lint and example suite. CI then runs `bundle exec rake spikes` separately. The Shared Gems spike has a separate runner and version prerequisites documented in its README; it is not included in the `spikes` aggregate.
