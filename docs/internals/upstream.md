# Upstream status

What Carton needs from Ruby, RubyGems, and Bundler, and what is still open.
Propose an upstream change only for a failure that reproduces on current
releases and cannot be handled at the Carton boundary.

## Goal

Ordinary Bundler setup should work in separate Boxes:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler/setup'")
box2.eval("require 'bundler/setup'")
```

Each Box keeps its own load path, loaded features, gem activation, and
`Bundler` module, and Main Box is unchanged.

## Status on Ruby 4.0.7 with Bundler 4.0.23

Nothing blocks Carton. Carton patches nothing in RubyGems or Bundler, and its
path-gem and nested-bundle tests pass; strict gem Cartons call two Bundler
internals (below). See
[how-gems-work.md](how-gems-work.md#ruby-407-confirmed-behavior) for the full
list of confirmed behavior.

## Open items

### Ruby docs describe old Main Box creation

`doc/language/box.md` still says the main box is created "at the end of
Ruby's bootstrap", on both v4.0.7 and master. Since 4.0.6, Ruby initializes
Root and Main from Master before the prelude. The fix is one sentence, and
[root-box-vs-main-box.md](root-box-vs-main-box.md) has the sources.

### Resolve once, activate in many Boxes

Carton does this today: it reads the caller's `Gem.loaded_specs`, rebuilds
each spec in the new Box from YAML, and activates it. When the caller is
bundled, it also restricts the Box to the caller's locked specs. Bundler has
no public API for that, so `lib/carton/gem_activation.rb` calls two
internals:

- `Bundler.rubygems.instance_variable_get(:@replaced_methods)` to detect that
  the caller ran Bundler setup, and
- `Bundler.rubygems.replace_entrypoints(specs)`, the strict half of
  `Bundler::Runtime#setup`.

`Runtime#setup` cannot be reused for this because it also resolves, writes
`RUBYOPT`/`RUBYLIB`/`PATH`/`BUNDLER_*` into `ENV`, and may rewrite the
lockfile. Proposal for Bundler: a public way to apply an already-resolved
spec set to the current Box without those side effects, e.g.
`Bundler.activate(specs, strict: true)`, plus `Bundler.setup?` or similar to
ask whether setup ran. Carton's integration tests are the reproduction. This
fits the second milestone of
[Ruby #22275](https://bugs.ruby-lang.org/issues/22275). Draft proposal:
[dtcristo/carton#16](https://github.com/dtcristo/carton/issues/16). Not
blocking.

### `Bundler.setup` selects its Gemfile through `ENV`

`Bundler.setup` takes no Gemfile argument; `default_gemfile` reads
`BUNDLE_GEMFILE`. `Carton.setup_bundle` sets it and restores all of `ENV`
afterwards, so other threads can see a Carton's values during setup. A
`Bundler.setup(gemfile:, lockfile:)` that leaves `ENV` alone would remove
that. Propose only with a failing multi-threaded reproduction.

## Resolved

- **Bundler setup writes subprocess `ENV`.** `Bundler::Runtime#setup` exports
  `RUBYOPT=-rbundler/setup`, `RUBYLIB`, `BUNDLER_SETUP`, `GEM_HOME`, `PATH`,
  and `BUNDLER_ORIG_*`, and `ENV` is process-global. Carton handles it by
  restoring all of `ENV` after `setup_bundle`, so no Bundler change is needed.
  Revisit only if a Carton needs its own subprocesses to inherit its bundle.
- **Ruby 4.0.7.** The gem prelude no longer runs `BUNDLER_SETUP` outside Main
  Box, per [Bug #22123](https://bugs.ruby-lang.org/issues/22123) and
  [this commit](https://github.com/ruby/ruby/commit/e9bccf88c1). On 4.0.6, a fresh Box under
  `bundle exec` re-ran the caller's `bundler/setup` while loading RubyGems.
  That inherited gem paths into new Boxes and broke Box creation after
  `bundler/setup`, so Carton purged gem paths and cleared `BUNDLER_SETUP`
  around `Ruby::Box.new`. Both workarounds are gone.
- **Bundler 4.0.23.** `RUBY_BOX=1 bundle exec` evaluates gemspecs. With 4.0.16
  it failed with `uninitialized constant Gem::Specification`.
- **Ruby 4.0.6.** The Master Box made Box contents independent of creation
  time, and each Box got its own RubyGems registries. Carton's RubyGems
  registry split and path-gem `full_require_paths` patch became unnecessary.
- **Ruby 4.0.5.** Boxed `Symbol#to_proc` and `super` dispatch failures do not
  reproduce on 4.0.6 or later.

### Template Boxes

Sharing monkey patches across Cartons costs a full load per Box (about 830ms
for Active Support's core extensions). Requiring them into `Ruby::Box.master`
once works on 4.0.7 and later Boxes inherit them, but Ruby documents that no
code runs in Master. Ask whether preparing Master before Boxes exist is
supported, or for an explicit API such as `Ruby::Box.new(template: box)`, with
shared-object semantics documented. See
[how-boxes-work.md](how-boxes-work.md#the-master-box-on-ruby-407) and
[examples/master_prelude](../../examples/master_prelude/README.md). Draft
proposal with a standalone reproduction:
[dtcristo/carton#25](https://github.com/dtcristo/carton/issues/25). Not
blocking.

## Ideas not pursued

- **Constant binding in patterns** (`import(path) => { Name: }`). The syntax is
  free today, but Matz keeps pattern targets to locals and `{ X: }` already
  reads a constant. Carton uses `export_default` and plain constant assignment
  instead. See
  [constant-binding-patterns.md](constant-binding-patterns.md).

## Non-goals

- process-local `ENV`,
- a general multi-context `Bundler.reset!`,
- convenience APIs used only by Carton.
