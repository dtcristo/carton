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

The remaining behavior claims below came from Ruby 4.0.5 and require fresh
4.0.6 reproduction before any upstream patch is proposed.

## Ruby 4.0.5 candidate blockers

### Prelude visibility

On Ruby 4.0.5, `RUBY_BOX=1 bundle exec` could load Bundler from `<internal:gem_prelude>` before
`Gem::Specification` is visible where Bundler evaluates the application
gemspec. The process fails before application code starts.

First rerun the regression on 4.0.6 using ordinary `bundle exec` with Boxes
enabled and a Gemfile containing `gemspec`.

### Boxed method dispatch through `Symbol#to_proc`

In the Ruby 4.0.5 boxed path-bundle integration prototype, direct dispatch to
`spec.expanded_dependencies` works while:

```ruby
specs.flat_map(&:expanded_dependencies)
```

does not see the boxed method. Replacing the symbol proc with an explicit block
only moves the failure forward; it is diagnostic, not a Bundler fix.

If this reproduces on 4.0.6, Ruby needs a focused `test_box.rb` regression.

### Boxed `super` dispatch

After the symbol-proc call is expanded, the second boxed bundle reaches
`Bundler::Dependency#initialize`. Its `super` call resolves to
`BasicObject#initialize` instead of boxed `Gem::Dependency#initialize`.

If this reproduces on 4.0.6, Ruby needs a focused regression covering `super`
from a Box-loaded subclass to the correct superclass method.

## Recommended order

1. Run the full path-bundle and `bundle exec` regressions on Ruby 4.0.6.
2. Add minimal regressions only for failures that reproduce.
3. Fix symbol-proc, `super`, and prelude failures independently if present.
4. Rerun the integration spec after each fix.

Keep each change surgical. The integration failure does not justify changing
Ruby boot order, making `ENV` box-local, or adding gem policy to the VM.

## Acceptance criteria

Ruby-side work is complete when:

1. direct and symbol-proc method calls select the same boxed method,
2. boxed `super` selects the correct superclass implementation,
3. `RUBY_BOX=1 bundle exec` can evaluate an application gemspec,
4. the RubyGems/Bundler boxed path-bundle integration reaches normal exit,
5. non-box behavior remains unchanged.

## Upstream stance

Ruby 4.0.6 supplies the intended isolation model. Establish current failures
against that model before proposing correctness fixes; do not carry 4.0.5 boot
or inheritance assumptions into upstream work.
