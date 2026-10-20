# Upstream status

What Carton needs from Ruby, RubyGems, and Bundler, and what is still open. Propose an upstream change only for a failure that reproduces on current releases and cannot be handled at the Carton boundary.

## Goal

Ordinary Bundler setup should work in separate Boxes:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler/setup'")
box2.eval("require 'bundler/setup'")
```

Each Box keeps its own load path, loaded features, gem activation, and `Bundler` module, and Main Box is unchanged.

## Status on Ruby 4.0.7 with Bundler 4.0.23

Nothing blocks Carton. Carton patches nothing in RubyGems or Bundler, and its path-gem and nested-bundle tests pass; restricting a Gem Carton to the importer's lockfile calls two Bundler internals (below). See [how-gems-work.md](how-gems-work.md#ruby-407-confirmed-behavior) for the full list of confirmed behavior.

## Open items

### Ruby's Box docs are stale

On v4.0.7 and master, `doc/language/box.md` still says the Main Box is created "at the end of Ruby's bootstrap", though since 4.0.6 Ruby initializes Root and Main from Master before the prelude. The same section opens with an unfinished sentence, "Ruby bootstrap runs in the root box, and a". The `Ruby::Box` class docs also omit `Ruby::Box.master`, `.root`, and `.main`, which Ruby defines only when Boxes are enabled. Each fix is small; [box-names.md](box-names.md#stale-upstream-docs) has the sources.

### Resolve once, activate in many Boxes

Carton does this today: it reads the importer's `Gem.loaded_specs`, rebuilds each spec in the new Box from YAML, and activates it. When the importer is bundled, it also restricts the Box to the caller's locked specs. Bundler has no public API for that, so `lib/carton/gem_activation.rb` calls two internals:

- `Bundler.rubygems.instance_variable_get(:@replaced_methods)` to detect that the importer ran Bundler setup, and
- `Bundler.rubygems.replace_entrypoints(specs)`, the strict half of `Bundler::Runtime#setup`.

`Runtime#setup` cannot be reused for this because it also resolves, writes `RUBYOPT`/`RUBYLIB`/`PATH`/`BUNDLER_*` into `ENV`, and may rewrite the lockfile. Rebuilding specs from YAML also loads Psych into every new Box, about 86 ms per Gem Carton ([performance.md](../performance.md)).

[Ruby #22275](https://bugs.ruby-lang.org/issues/22275) tracks Box support in RubyGems and Bundler. Its suites pass under `RUBY_BOX=1`, but several core design decisions are open. On 2026-09-25 it proposed not loading RubyGems and Bundler into Boxes by default, and creating a Box from an already-resolved load path instead. That fits Carton better than a Bundler activation API: Carton would compute a Gem Carton's load path once and hand it to the Box, with no spec rebuilding, no Psych, and no Bundler internals. Comment there with Carton's use case; the older activation-API draft is [dtcristo/carton#16](https://github.com/dtcristo/carton/issues/16). Not blocking.

### `Bundler.setup` selects its Gemfile through `ENV`

`Bundler.setup` takes no Gemfile argument; `default_gemfile` reads `BUNDLE_GEMFILE`. `Carton.setup_bundle` sets it and restores all of `ENV` afterwards, so other threads can see a Carton's values during setup. A `Bundler.setup(gemfile:, lockfile:)` that leaves `ENV` alone would remove that. Propose only with a failing multi-threaded reproduction.

### Template Boxes

Sharing monkey patches across Cartons costs a full load per Box (about 830ms for Active Support's core extensions). Requiring them into `Ruby::Box.master` once works on 4.0.7 and later Boxes inherit them, but Ruby documents that no code runs in Master, and Master should stay clean. Ask for official template Box support instead. Box copy-on-write assumes Master is the only copy source (only builtins get per-Box copies), so the draft states requirements and implementation questions rather than an API. #22275 defines no template mechanism yet. See [how-boxes-work.md](how-boxes-work.md#the-master-box-on-ruby-407) and [examples/master_prelude](../../examples/master_prelude/README.md). Draft proposal with a standalone reproduction: [dtcristo/carton#25](https://github.com/dtcristo/carton/issues/25). Not blocking.

### Userspace shared definitions and visibility isolation

The [Shared Gems spike](../../spikes/shared_gems/results.md) demonstrates method transplantation and selected Active Support/Rails-domain behavior without mutating Master. This narrows the missing template capability to faithfully copying builtin extension state, including constants, state and ancestors without rerunning callbacks. Definition installation alone does not solve gem activation or require deduplication. Ordinary Gem Carton activation and the unmodified Rails example fail under the experimental hook; it is not a replacement for the current loader.

Ruby 4.0.7 also has an independent [visibility isolation reproduction](../../spikes/shared_gems/09_visibility_leak.rb): `protected :upcase` in an Optional Box affects Main and Master. `rb_export_method` mutates visibility on an entry shared by copied method tables. A narrow upstream fix would clone the entry into the current Box's writable table before changing its flags, while sharing its underlying definition. This is a source-backed diagnosis, not an implemented or upstream-accepted fix. Report it separately from template Boxes.

## Resolved

- **Autoloads skipped `Kernel#require` patches.** Under `RUBY_BOX=1`, an autoload loaded its file with `Ruby::Box#require`, bypassing the patches Zeitwerk and Bootsnap rely on ([Bug #21830](https://bugs.ruby-lang.org/issues/21830)). Ruby master fixes it ([PR #18534](https://github.com/ruby/ruby/pull/18534)); on 4.0.7, Carton routes each Box's autoload `require` through `Kernel#require` (see [how-boxes-work.md](how-boxes-work.md#which-box-runs-an-autoload)).

- **Bundler setup writes subprocess `ENV`.** `Bundler::Runtime#setup` exports `RUBYOPT=-rbundler/setup`, `RUBYLIB`, `BUNDLER_SETUP`, `GEM_HOME`, `PATH`, and `BUNDLER_ORIG_*`, and `ENV` is process-global. Carton handles it by restoring all of `ENV` after `setup_bundle`, so no Bundler change is needed. Revisit only if a Carton needs its own subprocesses to inherit its bundle.
- **Ruby 4.0.7.** The gem prelude no longer runs `BUNDLER_SETUP` outside Main Box, per [Bug #22123](https://bugs.ruby-lang.org/issues/22123) and [this commit](https://github.com/ruby/ruby/commit/e9bccf88c1). On 4.0.6, a fresh Box under `bundle exec` re-ran the caller's `bundler/setup` while loading RubyGems. That inherited gem paths into new Boxes and broke Box creation after `bundler/setup`, so Carton purged gem paths and cleared `BUNDLER_SETUP` around `Ruby::Box.new`. Both workarounds are gone.
- **Bundler 4.0.20.** Gemfiles can evaluate gemspecs inside a Carton Box. Earlier versions use Main Box's `TOPLEVEL_BINDING`, so the gemspec gets the wrong `Gem::Specification` and fails with `undefined method 'source='`. [RubyGems PR #9809](https://github.com/ruby/rubygems/pull/9809) fixed this in [4.0.20](https://github.com/ruby/rubygems/releases/tag/v4.0.20), Carton's minimum supported Bundler version. On Ruby 4.0.7, a Carton calling `setup_bundle` with a `gemspec` Gemfile reproduces the failure on Bundler 4.0.19 and succeeds on 4.0.20. The earlier `uninitialized constant Gem::Specification` failure under `bundle exec` also needed Ruby's #22123 fix above.
- **Ruby 4.0.6.** The Master Box made Box contents independent of creation time, and each Box got its own RubyGems registries. Carton's RubyGems registry split and path-gem `full_require_paths` patch became unnecessary.
- **Ruby 4.0.5.** Boxed `Symbol#to_proc` and `super` dispatch failures do not reproduce on 4.0.6 or later.

## Ideas not pursued

- **Per-Box copies for every class.** Classes created in User Boxes have one shared definition, so reopening a Carton's class from another Box changes it everywhere. Giving them per-Box copies like builtins would isolate reopens, but the same object would then behave differently depending on the calling Box. Recorded for context; raise it with the template Box proposal ([dtcristo/carton#25](https://github.com/dtcristo/carton/issues/25)) only if maintainers ask about class isolation.
- **Constant binding in patterns** (`import(path) => { Name: }`). The syntax is free today, but Matz keeps pattern targets to locals and `{ X: }` already reads a constant. Carton uses `export` and plain constant assignment instead. See [constant-binding-patterns.md](constant-binding-patterns.md).

## Non-goals

- process-local `ENV`,
- a general multi-context `Bundler.reset!`,
- convenience APIs used only by Carton.
