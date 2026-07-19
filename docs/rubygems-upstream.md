# RubyGems/Bundler upstream plan for boxed bundle isolation

## Goal

Keep ordinary Bundler setup isolated in separate `Ruby::Box` instances,
including bundles that select conflicting versions of the same path gem.

## What already works on Ruby 4.0.6

Stock RubyGems/Bundler under Ruby 4.0.6, exercised through Carton's acceptance
suite and Bundler example, gives separate Boxes:

- distinct `Gem.loaded_specs`,
- isolated `$LOAD_PATH` mutation,
- conflicting non-path bundle activation without Main Box leakage,
- app-bundle path gems importable as Cartons,
- Imported Cartons with their own Gemfiles activating intended versions.

Carton still scopes `BUNDLE_GEMFILE`, clears stale `BUNDLE_LOCKFILE`, installs a
path-gem load-path compatibility patch, and clears `BUNDLER_SETUP` around
optional Box construction so Master-based Boxes do not re-enter the caller's
`bundler/setup` through RubyGems' process-global hook.

## Ruby 4.0.6 startup failure

`RUBY_BOX=1 bundle exec` still fails when the Gemfile evaluates a gemspec:

```text
Bundler::GemspecError: uninitialized constant Gem::Specification
```

That failure is owned by Ruby prelude ordering under Boxes. Do not change
Bundler to paper over missing `Gem::Specification` visibility.

## Historical Ruby 4.0.5 path-gem notes

Ruby 4.0.5 path-gem setup previously failed during boxed method dispatch
(`Symbol#to_proc` / `super`). Those diagnoses are historical. On Ruby 4.0.6 the
Carton path-gem acceptance boundary passes; do not propose Bundler changes for
that older failure unless a current integration reproduces it.

## RubyGems/Bundler work

Keep the path-bundle integration coverage as the downstream acceptance test.
No RubyGems or Bundler patch is justified by the current 4.0.6 Carton suite.

Only revisit RubyGems/Bundler if, after the Ruby prelude fix, a residual
path-gem or registry failure remains that cannot be solved at the Carton
boundary without breaking ordinary non-box setup.

Bundler still selects its Gemfile through process-global environment state.
Carton may continue scoping `BUNDLE_GEMFILE`, clearing `BUNDLE_LOCKFILE`, and
guarding `BUNDLER_SETUP` around Box creation; that is separate from activation
isolation.

## Integration acceptance criteria

### Two boxed path bundles / Imported Carton bundles

- separate Boxes each run ordinary `require "bundler/setup"`,
- each activates its own intended gem versions,
- path gems resolve and import successfully,
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

RubyGems/Bundler isolation is already sufficient for Carton's per-Carton bundle
model on Ruby 4.0.6. Upstream priority stays on the Ruby prelude/`bundle exec`
failure; do not open Bundler changes for historical 4.0.5 path-gem dispatch
without a fresh failing integration.
