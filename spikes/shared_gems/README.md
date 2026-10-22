# Shared Gems Boxes prototype

Throwaway Ruby 4.0.7 experiments. No production API or runtime changes. Read [results.md](results.md) before using the helper.

A builtin method defined in one Optional Box can be installed in another with `define_method` and retain its original execution Box. Full Active Support passes the selected checks when installation covers its changed builtin methods and ancestors. Normal gem loading and arbitrary isolation do not follow from that result.

## Run

From the repository root, with Ruby 4.0.7+ and Bundler 4.0.23:

```sh
BUNDLE_GEMFILE=spikes/shared_gems/Gemfile bundle install
RUBY_BOX=1 ruby spikes/shared_gems/run.rb
```

The runner starts a fresh process for each case and checks both successful experiments and specific expected failures. Recorded failure expectations target Ruby 4.0.7; a later Ruby release may require a fresh classification. The Rails case also needs the existing example bundle:

```sh
BUNDLE_GEMFILE=examples/rails/Gemfile bundle install
```

`11_gem_contract.rb` checks independent Active Support 8.1.2 alongside the shared 8.1.4 bundle, and needs both versions installed. The Gem Carton failure case uses the existing `test/fixtures/shared_gems` bundle. The repository's full `bundle exec rake` installs that fixture's BigDecimal versions. These are explicit experiment prerequisites, not new production dependencies.

## Experiments

| Script | Question |
| --- | --- |
| `01_method_transplant.rb` | Original handoff probe, preserved with unchanged expectations. Fails on missing `UnboundMethod#box`. |
| `02_builtin_isolation.rb` | Does transplantation preserve behavior, provenance and local overrides? |
| `03_shared_constants.rb` | Which class/module objects and mutable state are shared? |
| `04_modules_and_ancestors.rb` | Do include, prepend, callbacks and super compose? |
| `00_discovery.rb` | Can reflection detect method and ancestor changes? |
| `05_active_support.rb --targeted` | Can two fresh Boxes use targeted extensions without requiring them? |
| `05_active_support.rb` | What does the initial builtin list miss? Expected failure for `Enumerable#compact_blank`. |
| `05_active_support.rb --extended` | Does extending discovery to Enumerable, Range, Float and Regexp fix the selected full-core-extension checks? |
| `06_lazy_loading.rb` | Where do lazy requires/autoloads run, and what happens on a local require? |
| `07_multiple_cartons.rb` | Can a process-local hook install definitions before ordinary Carton entrypoints run? |
| `07_multiple_cartons.rb --gem` | Does that hook survive existing Gem Carton activation? Expected failure. |
| `08_benchmark.rb` | What are time, retained RSS, source compilation and feature-load costs at 1, 5, 10, 25 and 50 Boxes? |
| `09_visibility_leak.rb` | Does a visibility-only builtin mutation stay isolated? Verified VM failure, asserted in a disposable process. |
| `10_rails.rb` | Can two Active Record domain Cartons use shared Rails dependencies and SQLite? |
| `10_rails.rb --existing` | Can the same hook run the unmodified Rails-in-Cartons example? Expected activation failure. |
| `11_gem_contract.rb` | Do JSON, Zeitwerk, bundle restrictions and independent version selection follow the intended model? |

The prototype helper retains method objects and an explicit manifest in memory. Its `summary` lists installed method names, visibility, removals, ancestor additions and unsupported state changes. It binds newly loaded top-level constants by identity. It does not copy loaded features, intercept require, activate child gems, or claim to copy a complete Box. Existing top-level autoloads are not transferred. The integration hook uses private Carton internals and exists only in the scripts' processes.

## Benchmarks

Each row runs in a fresh Ruby process. Master mutation occurs only in the `master` control's disposable worker.

```sh
RUBY_BOX=1 ruby spikes/shared_gems/08_benchmark.rb > spikes/shared_gems/benchmark_active_support.json
RUBY_BOX=1 ruby spikes/shared_gems/08_benchmark.rb --synthetic > spikes/shared_gems/benchmark_synthetic.json
```

The four controls load dependencies independently, install shared definitions, use the unsupported Master prelude, and run existing Carton imports with independent loading. The synthetic dependency and Active Support results are separate. Rails persistence correctness is separate from these timings. No Rails application performance claim follows from the Active Support benchmark.
