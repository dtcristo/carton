# RubyGems/Bundler upstream plan for boxed bundle isolation

## Goal

Keep ordinary Bundler setup isolated in separate `Ruby::Box` instances,
including bundles that select conflicting versions of the same path gem.

## What already works

On the supported stack, stock RubyGems/Bundler already gives separate boxes:

- distinct `Gem.loaded_specs`,
- distinct `Gem::Specification.specification_record` state,
- distinct Bundler modules,
- isolated `$LOAD_PATH` mutation,
- conflicting non-path bundle activation without main-box leakage.

An already-bundled main box can also activate a conflicting non-path version in
a child box. A broad RubyGems registry-localization patch is therefore not an
upstream target.

## Current integration failure

The upstream prototype creates two path bundles containing different versions
of the same gem, runs `bundler/setup` in separate boxes, and checks that the main
box's activation state and load path remain unchanged.

On the supported runtime, path-gem setup first fails while Bundler assigns
`Gem::Specification#source=`. With the candidate caller-box runtime semantics,
setup advances and exposes two Ruby dispatch bugs:

1. `flat_map(&:expanded_dependencies)` cannot see a boxed method that a direct
   call can see.
2. `Bundler::Dependency#initialize` resolves `super` to
   `BasicObject#initialize` instead of boxed `Gem::Dependency#initialize`.

Changing Bundler's symbol proc to an explicit block is only a diagnostic. It
does not solve the second failure and should not be proposed upstream.

## RubyGems/Bundler work

Keep the path-bundle integration spec as the downstream acceptance test. Once
Ruby fixes boxed method dispatch, rerun it before proposing any RubyGems or
Bundler change.

Only change RubyGems/Bundler if the integration still fails after the Ruby
fixes. Any remaining patch must be limited to the failing path-gem behavior and
must preserve normal non-box setup.

Bundler still selects its Gemfile through process-global environment state.
Carton may continue scoping `BUNDLE_GEMFILE` and clearing `BUNDLE_LOCKFILE`;
that is separate from activation isolation.

## Integration acceptance criteria

### Two boxed path bundles

- box A and box B each run ordinary `require "bundler/setup"`,
- each activates its own path-gem version,
- each can require that gem,
- main `Gem.loaded_specs` and `$LOAD_PATH` remain unchanged,
- the process exits normally.

### Startup

- `RUBY_BOX=1 bundle exec` can evaluate a Gemfile containing `gemspec`,
- application code starts normally.

### Compatibility

- normal Bundler setup outside boxes remains unchanged,
- no new public Bundler API is required,
- no Carton-specific behavior enters RubyGems/Bundler.

## Non-goals

- a new Gemfile-selection API,
- process-local `ENV`,
- a general multi-context `Bundler.reset!`,
- a RubyGems registry split already supplied by the runtime,
- convenience APIs used only by Carton.

## Upstream stance

The RubyGems/Bundler model is already sufficiently isolated for ordinary gems.
Keep the end-to-end path-gem regression ready, fix the proven Ruby dispatch
bugs first, then upstream only any residual RubyGems/Bundler change the passing
Ruby semantics demonstrate is necessary.
