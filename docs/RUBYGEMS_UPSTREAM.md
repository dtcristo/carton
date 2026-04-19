# Minimal RubyGems/Bundler upstream plan for boxed bundle isolation

## High-level goal

Make this model work reliably inside one process:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler/setup'")
box2.eval("require 'bundler/setup'")
```

with each box getting:

- its own activated-gem view,
- its own RubyGems spec registry view,
- its own Bundler module state,
- its own `$LOAD_PATH` mutation,

without requiring Carton to patch a large amount of private RubyGems/Bundler internals forever.

## The key conclusion

**No RubyGems/Bundler upstream change is required to prove the model in Carton first.**

The source reading and runtime probes point to a smaller first step:

1. prototype the behavior as a Carton-side monkey patch inside the import box,
2. prove exactly which RubyGems methods and registries must be split,
3. upstream only the small, necessary surface that turns that patch into supported behavior.

That means the upstream target should be **stability for an already-proven patch**, not a speculative redesign of Bundler.

## Non-goals

This plan intentionally does **not** ask for:

- a brand new public Bundler API for selecting Gemfiles by path,
- a general "multiple Bundlers in one process" feature unrelated to boxes,
- process-local `ENV`,
- convenience APIs for load-path extraction without setup,
- broad refactors to Bundler reset/environment helpers,
- any change justified only because it would be nicer for Carton.

The only thing that matters here is:

> can `require "bundler/setup"` inside a box produce a box-local activation world?

## Why this is mostly a RubyGems/Bundler problem, not a Ruby-core problem

The probes and source reading show:

1. `$LOAD_PATH` is already box-local.
2. `$LOADED_FEATURES` is already box-local.
3. `require` already resolves against the loading box.
4. Bundler itself can already load per box if first required in the box.
5. `Gem.loaded_specs` can already be localized by replacing `@loaded_specs` inside the box.

So the missing piece is not "make boxes capable of isolated gem state."

The missing piece is:

> make the RubyGems runtime view that Bundler patches become box-local in a supported way.

## What is actually failing today

The current failure is not one thing. It is two related things:

### 1. RubyGems was loaded in the root box during prelude

So `require "rubygems"` inside a later box is not a fresh load. The box starts from a root-derived RubyGems world.

### 2. Some RubyGems singleton methods loaded in the root box keep acting like root-defined behavior

Direct probe results:

- `Gem.loaded_specs` starts shared, but can be split by setting `Gem.@loaded_specs` inside the box.
- `Gem::Specification.@specification_record` can be set inside the box.
- `Gem::Specification.@unresolved_deps` can be set inside the box.
- but methods such as `Gem::Specification.all=` still behave like shared/root behavior until redefined inside the box.

That is the most important upstream fact.

The problem is **not** "Bundler is globally singleton in an unavoidable way."

The problem is:

> Bundler talks to RubyGems methods that were defined in the root RubyGems world, and those methods are still steering shared registry behavior.

## Minimal upstream direction

The minimal worthwhile upstream work is:

1. upstream the small RubyGems state split that Carton currently monkey patches in `Carton.bootstrap_rubygems!`,
2. keep Carton's explicit pre-Bundler bootstrap model if that remains sufficient,
3. only touch Bundler if RubyGems cannot make that bootstrap self-contained.

In other words:

> do not invent a new Bundler architecture; make the RubyGems runtime view that Bundler mutates become box-local, then keep `require "bundler/setup"` as ordinary setup.

## Recommended implementation order

## Phase 0: prove the patch in Carton first

Before any upstream work, Carton should prove a box-local bootstrap entirely in user space.

That patch should run inside the target box before `require "bundler/setup"`.

The prototype should:

1. duplicate `Gem.@loaded_specs`,
2. duplicate or rebuild the `Gem::Specification` registry state used by Bundler,
3. redefine the handful of RubyGems singleton methods that must stop using root-loaded behavior,
4. then load Bundler normally inside the box.

If that prototype fails, upstream should not start yet.

That proof now exists in Carton as the explicit sequence:

```ruby
Carton.bootstrap_rubygems!
Carton.with_bundle { require "bundler/setup" }
```

If that model keeps holding up, upstream can stay tiny and precise.

## Phase 1: add a RubyGems internal bootstrap for boxed state

RubyGems should gain an internal helper that does one job:

> materialize box-local mutable RubyGems state in the current box before Bundler starts mutating it.

This does **not** need to be a large public API.

Carton is already proving the behavior from user space; upstream should absorb the RubyGems half of that behavior without forcing Carton to keep monkey-patching private RubyGems internals forever. The exact internal shape is less important than the behavior.

### State that should become box-local for Bundler setup

At minimum, the bootstrap must localize the state Bundler actually mutates:

#### `Gem`

- `@loaded_specs`
- any path caches that `Gem.clear_paths` or `Gem.use_paths` mutate
- `@discover_gems_on_require` if Bundler will flip it

#### `Gem::Specification`

- `@specification_record`
- `@unresolved_deps`
- `@@dirs` only if the boxed flow mutates directories

### Methods that likely need a boxed override or boxed implementation

At minimum, the boxed bootstrap needs a safe implementation path for methods Bundler touches during setup:

#### On `Gem`

- `clear_paths`
- any other helper that writes the caches behind gem-path resolution

#### On `Gem::Specification`

- `specification_record`
- `all`
- `all=`
- `_all`
- `reset`
- `unresolved_deps`

These are not guesses from style review; they follow directly from:

- Bundler's `stub_rubygems`,
- Bundler's `replace_entrypoints`,
- the probes where `Gem::Specification.all = ...` stayed effectively shared until redefined inside the box.

### Keep the scope narrow

Do **not** attempt to make every RubyGems API box-aware in the first pass.

The first pass only needs to support:

- `require "bundler/setup"` inside a box,
- later `require` calls against that bundle,
- explicit activation conflicts staying local to that box.

If broader RubyGems-in-box support becomes desirable later, expand from there.

## Phase 2: keep Bundler untouched unless RubyGems cannot stand alone

Carton's current working model does **not** require any Bundler patch:

1. `Carton.bootstrap_rubygems!`
2. `Carton.with_bundle { require "bundler/setup" }`

That is acceptable if the goal is to upstream only what is strictly necessary.

So the first upstream target should be:

- RubyGems owns the boxed mutable state split,
- `require "bundler/setup"` itself stays unchanged,
- Carton keeps calling its explicit bootstrap before Bundler setup.

Only revisit a tiny Bundler-side hook if RubyGems cannot make the bootstrap reliable without one.

## Phase 3: leave Gemfile selection alone unless it still blocks the design

Bundler currently finds the active Gemfile/lockfile through:

- `ENV["BUNDLE_GEMFILE"]`
- `ENV["BUNDLE_LOCKFILE"]`
- current working directory search

That is awkward under boxes because `ENV` is process-global.

But it is still **orthogonal** to the main activation-isolation problem.

So the first upstream plan should **not** ask for a new `Bundler.setup(gemfile: ...)` API.

For the first working design:

- Carton can continue to hand off `BUNDLE_GEMFILE` and clear stale `BUNDLE_LOCKFILE`,
- or the carton entry file can set those environment details before `require "bundler/setup"`,
- while the real upstream work stays focused on activation isolation.

Only revisit explicit-Gemfile APIs if the boxed activation patch proves good and `ENV` ergonomics become the remaining blocker.

## Detailed reasoning for the minimal surface

## Why `Gem.loaded_specs` alone is not enough

Bundler's runtime path does more than mark loaded specs.

It also:

- replaces `Kernel#gem`,
- stubs RubyGems' available-spec view,
- calls `Gem::Specification.all = specs`,
- hooks reset behavior,
- clears RubyGems path caches.

So a design that only duplicates `Gem.loaded_specs` will still leak through `Gem::Specification` and path-reset behavior.

## Why the bootstrap should live in RubyGems, not only in Bundler

Bundler is the caller, but RubyGems owns the mutable registries.

If Bundler hardcodes all of the splitting logic itself, it will need to know too much about RubyGems internals.

The cleaner minimal split is:

- RubyGems knows how to create a localized mutable view of its own state,
- Bundler asks RubyGems to do that before setup.

That keeps the patch surface small and places ownership correctly.

## Why the bootstrap should be internal first

The exact method list is still best validated by the Carton prototype.

Publishing a broad public API too early would freeze details that may not actually be necessary.

So the preferred path is:

1. internal helper first,
2. use it in Bundler,
3. only make it public if external embedders truly need it directly.

## Tests and acceptance criteria

RubyGems/Bundler upstream work is only done when these pass:

### Single boxed bundle

- main process unbundled,
- box requires `bundler/setup`,
- bundle gems appear in that box,
- main box `Gem.loaded_specs` and `$LOAD_PATH` do not gain those activations.

### Two boxed bundles

- box A and box B each run `bundler/setup`,
- they can activate conflicting versions of the same gem,
- each box sees its own activated version through RubyGems,
- main remains unaffected.

### No regression outside boxes

- normal Bundler setup outside boxes behaves exactly as before,
- existing Bundler CLI/runtime behavior stays unchanged.

## Interaction with Ruby upstream work

This RubyGems/Bundler plan depends on one Ruby-side fix:

- Ruby must stop crashing on normal exit when Bundler is required in two boxes.

That crash is not a reason to broaden RubyGems scope. It is just the boundary between the RubyGems plan and the Ruby plan.

## What should be removed from Carton's old upstream wishlist

These older ideas should stay out of the first upstream push unless a proven prototype later shows they are still required:

- explicit Gemfile-selection APIs in Bundler,
- "load paths only" Bundler APIs,
- stronger `Bundler.reset!` multi-context promises,
- general convenience helpers for embedded runtimes.

Those may be nice. They are not the minimal path to boxed `bundler/setup`.

## Recommended stance

If this gets discussed upstream, the message should be:

> We already have most of the box isolation we need. We are not asking for a new bundler model. We are asking for the smallest RubyGems/Bundler change that lets Bundler mutate a box-local RubyGems runtime view instead of the prelude-loaded root view.

That is the narrowest accurate ask.
