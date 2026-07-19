# Ruby 4.0.6 upstream validation plan for boxed Bundler support

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

## Runtime baseline

Ruby 4.0.6 provides the Master-based Box model Carton targets:

- Root, Main, and optional Boxes copy immutable Master state,
- Main owns the top-level application,
- optional Boxes do not inherit Root or Main mutations,
- box-local `$LOAD_PATH` and `$LOADED_FEATURES`,
- box-local RubyGems activation and specification registries,
- distinct Bundler modules in separate boxes,
- independently loaded prelude helpers in user Boxes.

## Ruby 4.0.6 reproduction results

### Prelude visibility — still failing

On Ruby 4.0.6 with Bundler 4.0.16, `RUBY_BOX=1 bundle exec` still fails when the
Gemfile evaluates a gemspec:

```text
Bundler::GemspecError: uninitialized constant Gem::Specification
```

Bundler is loaded from `<internal:gem_prelude>` before `Gem::Specification` is
visible where the application gemspec is evaluated. Application code never
starts. This remains a Ruby/prelude correctness issue, not a Carton API gap.

### Path-gem Carton boundary — passing

The repository Bundler example and integration tests pass on Ruby 4.0.6:

- an app bundle path gem is importable as a Carton,
- separate Cartons activate their intended gem versions,
- Main Box activation and load-path state remain unchanged.

Carton clears process-global `BUNDLER_SETUP` around optional Box construction so
a fresh Master-based Box does not re-enter the caller's `bundler/setup` through
RubyGems' load hook. That is Carton adaptation to process-global Bundler ENV,
not an upstream Ruby patch.

### Historical dispatch probes

Simple same-Box `Symbol#to_proc` and `super` probes succeed on Ruby 4.0.6. The
older Ruby 4.0.5 path-bundle failure that pointed at those dispatch paths is no
longer blocking Carton's acceptance suite. Do not reopen upstream dispatch work
unless a current failing integration reproduces it.

## Recommended order

1. Keep Carton's path-gem and nested-bundle acceptance coverage green on 4.0.6.
2. Fix `RUBY_BOX=1 bundle exec` gemspec evaluation under Boxes so `Gem::Specification`
   is visible before Bundler evaluates the application gemspec.
3. Add a focused Ruby regression for that prelude ordering failure.
4. Only revisit symbol-proc or `super` upstream work if a current integration fails.

Keep each change surgical. The remaining startup failure does not justify
changing Ruby boot order broadly, making `ENV` box-local, or adding gem policy
to the VM.

## Acceptance criteria

Ruby-side work for Carton's current needs is complete when:

1. `RUBY_BOX=1 bundle exec` can evaluate an application gemspec and start app code,
2. Carton's path-gem and nested-bundle acceptance suite remains green,
3. non-box behavior remains unchanged.

## Upstream stance

Ruby 4.0.6 supplies the intended isolation model for per-Carton Bundler setup.
The remaining upstream blocker confirmed on 4.0.6 is boxed `bundle exec`
prelude/gemspec evaluation.
