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
path-gem and nested-bundle tests pass. See
[how-gems-work.md](how-gems-work.md#ruby-407-confirmed-behavior) for the full
list of confirmed behavior.

## Open items

None of these block Carton.

### Bundler setup writes subprocess `ENV`

`Bundler::Runtime#setup` calls `SharedHelpers.set_bundle_environment`, which
exports `RUBYOPT=-rbundler/setup`, `RUBYLIB`, `BUNDLER_SETUP`, `GEM_HOME`,
`PATH`, and `BUNDLER_ORIG_*` so subprocesses inherit the bundle. `ENV` is
process-global, so a Carton's setup changes the environment Main's
subprocesses see. The plan is for Carton to restore `ENV` itself, as tracked in
[todo.md](../todo.md).

An upstream option to set up a bundle in-process without exporting subprocess
environment, or to pass the Gemfile directly instead of through
`BUNDLE_GEMFILE`, would remove the need. Only propose it if restoring `ENV`
in Carton turns out not to be enough.

### Ruby docs describe old Main Box creation

`doc/language/box.md` still says the main box is created "at the end of
Ruby's bootstrap", on both v4.0.7 and master. Since 4.0.6, Ruby initializes
Root and Main from Master before the prelude. The fix is one sentence, and
[root-box-vs-main-box.md](root-box-vs-main-box.md) has the sources.

## Resolved

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

## Non-goals

- process-local `ENV`,
- a general multi-context `Bundler.reset!`,
- convenience APIs used only by Carton.
