# RubyGems/Bundler upstream status for boxed bundle isolation

## Goal

Keep ordinary Bundler setup isolated in separate `Ruby::Box` instances,
including bundles that select conflicting versions of the same gem.

## Status on Ruby 4.0.7 with RubyGems/Bundler 4.0.23

Stock RubyGems and Bundler give separate Boxes:

- distinct `Gem.loaded_specs` and specification registries,
- isolated `$LOAD_PATH` mutation,
- conflicting bundle activation without Main Box leakage,
- app-bundle path gems importable as Cartons,
- Imported Cartons with their own Gemfiles activating intended versions,
- a working `RUBY_BOX=1 bundle exec`, including gemspec evaluation.

Carton previously carried a RubyGems registry split, a Bundler spec
normalizer, and a path-gem `full_require_paths` patch. All three are gone; the
suite passes without them.

Bundler still selects its Gemfile through process-global `ENV`. Carton scopes
`BUNDLE_GEMFILE` and clears `BUNDLE_LOCKFILE` in `setup_bundle`; that is
separate from activation isolation and needs no upstream change.

## Upstream stance

No RubyGems or Bundler patch is justified by the current Carton suite. Revisit
only for a residual failure that reproduces on current releases and cannot be
solved at the Carton boundary without breaking ordinary non-box setup.

## Non-goals

- a new Gemfile-selection API,
- process-local `ENV`,
- a general multi-context `Bundler.reset!`,
- convenience APIs used only by Carton.
