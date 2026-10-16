# Ruby upstream status for boxed Bundler support

## Goal

Make ordinary Bundler setup reliable across `Ruby::Box` boundaries:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler/setup'")
box2.eval("require 'bundler/setup'")
```

Each box should keep its own load paths, loaded features, gem activation state,
and Bundler module without changing Main Box.

## Status on Ruby 4.0.7

No Ruby change is needed for Carton's current needs. With Bundler 4.0.23:

- Root, Main, and optional Boxes copy immutable Master state,
- optional Boxes start with no gem load paths or gem loaded features, even
  when Main ran under `bundle exec`,
- each Box has its own RubyGems activation and specification registries,
- separate Boxes load distinct Bundler modules,
- per-Carton bundles, conflicting versions, and app-bundle path gems pass
  Carton's acceptance suite,
- `RUBY_BOX=1 bundle exec` evaluates gemspecs and starts the app.

Carton patches nothing in RubyGems or Bundler. It only scopes `BUNDLE_GEMFILE`
and `BUNDLE_LOCKFILE`, because `ENV` is process-global by design.

## Historical findings

- Ruby 4.0.5: path-gem setup hit boxed `Symbol#to_proc` and `super` dispatch
  bugs.
- Ruby 4.0.6: fresh Boxes created under `bundle exec` inherited the bundle's
  gem paths, and a Box created after `bundler/setup` could re-enter the
  caller's setup through `BUNDLER_SETUP`. With Bundler 4.0.16,
  `RUBY_BOX=1 bundle exec` also failed with
  `uninitialized constant Gem::Specification` while evaluating a gemspec.

None of these reproduce on Ruby 4.0.7 with Bundler 4.0.23. Do not reopen them
without a current failing integration.

## Upstream stance

Keep Carton's path-gem and nested-bundle acceptance coverage green as the
regression signal. Propose a Ruby change only for a failure that reproduces on
the current release and cannot be handled at the Carton boundary.
