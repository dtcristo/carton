# Ruby upstream plan for boxed Bundler support

## Goal

Make ordinary Bundler setup reliable across `Ruby::Box` boundaries:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler/setup'")
box2.eval("require 'bundler/setup'")
```

Each box should keep its own load paths, loaded features, gem activation state,
and Bundler module without changing the main box.

## What already works

The supported runtime already provides:

- box-local `$LOAD_PATH` and `$LOADED_FEATURES`,
- box-local RubyGems activation and specification registries,
- distinct Bundler modules in separate boxes,
- conflicting non-path bundles in separate boxes,
- a conflicting child bundle under an already-bundled main box,
- clean ordinary process exit after Bundler loads in multiple boxes.

No new VM-level gem registry or Bundler namespace is needed.

## Current Ruby blockers

### Prelude visibility

`RUBY_BOX=1 bundle exec` can load Bundler from `<internal:gem_prelude>` before
`Gem::Specification` is visible where Bundler evaluates the application
gemspec. The process fails before application code starts.

The regression should exercise ordinary `bundle exec` with boxes enabled and a
Gemfile containing `gemspec`.

### Boxed method dispatch through `Symbol#to_proc`

In the boxed path-bundle integration prototype, direct dispatch to
`spec.expanded_dependencies` works while:

```ruby
specs.flat_map(&:expanded_dependencies)
```

does not see the boxed method. Replacing the symbol proc with an explicit block
only moves the failure forward; it is diagnostic, not a Bundler fix.

Ruby needs a focused `test_box.rb` regression proving that symbol-proc dispatch
uses the same boxed method lookup as a direct call.

### Boxed `super` dispatch

After the symbol-proc call is expanded, the second boxed bundle reaches
`Bundler::Dependency#initialize`. Its `super` call resolves to
`BasicObject#initialize` instead of boxed `Gem::Dependency#initialize`.

Ruby needs a focused regression covering `super` from a box-loaded subclass to
the correct superclass method across box class extensions.

## Recommended order

1. Add the two minimal method-dispatch regressions to Ruby.
2. Fix symbol-proc and `super` lookup independently.
3. Fix the boxed `bundle exec` prelude regression independently.
4. Rerun the RubyGems/Bundler path-bundle integration spec after each fix.

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

Ruby already supplies the right isolation model. The remaining work is a small
set of correctness fixes for method lookup and prelude loading across box
boundaries, not a redesign of `Ruby::Box` or gem activation.
