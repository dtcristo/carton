# Minimal Ruby upstream plan for boxed Bundler support

## High-level goal

Keep Ruby changes as small as possible while making this reliable:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler/setup'")
box2.eval("require 'bundler/setup'")
```

The desired end state is:

- Ruby keeps providing box-local `$LOAD_PATH` and `$LOADED_FEATURES`,
- RubyGems/Bundler make activation state box-local on top of that,
- Ruby itself does not crash or corrupt teardown when multiple boxes load Bundler.

## The key conclusion

**No broad Ruby-core redesign is justified by the current evidence.**

The source reading and probes strongly suggest:

1. Ruby already has the right loading model for this feature.
2. The main remaining Ruby blocker is a real `Ruby::Box` crash when Bundler is required in multiple boxes.
3. Ruby should not gain new box APIs or gem-loading APIs unless a RubyGems-only prototype proves they are truly necessary.

So the Ruby upstream plan should be intentionally small.

## What Ruby already gets right

These pieces are already in place:

### Box-local load state

`ruby/load.c` and `ruby/vm.c` already make:

- `$LOAD_PATH`
- `$LOADED_FEATURES`
- feature indexing
- `require` resolution

depend on `rb_loading_box()`.

That is exactly the right foundation for boxed `bundler/setup`.

### Root/main/user box model

`ruby/box.c` and `ruby/internal/box.h` already provide:

- a root box,
- a main user box,
- optional boxes created from the root box,
- per-box load data,
- per-box global-variable storage,
- per-box class-extension copy-on-write.

Again, that is already the model Carton wants.

### Box-local Bundler constants are already possible

Direct probes showed:

- `Bundler` is not preloaded by Ruby prelude,
- requiring `bundler` inside one box does not define `Bundler` in main,
- two boxes can get distinct `Bundler` module objects.

So Ruby does **not** need a new "per-box Bundler module" facility.

## The one Ruby change that does look necessary

## Fix the multi-box Bundler teardown crash

This is the concrete blocker observed in runtime probes.

### Reproduction

With `RUBY_BOX=1`:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler'; Bundler::VERSION")
box2.eval("require 'bundler'; Bundler::VERSION")
```

On Ruby `4.0.2`, execution succeeds, but the process aborts on normal exit with a malloc/free crash.

Important observations:

- one box requiring Bundler does not crash,
- two boxes requiring Bundler do crash,
- `Process.exit!(0)` avoids teardown and preserves expected per-box Bundler identity,
- this happens before trying conflicting Gemfiles,
- so this is a Ruby runtime issue even before RubyGems/Bundler activation isolation is solved.

### Why this is a Ruby issue

The reproducer only asks Ruby to:

- create two boxes,
- load the same large Ruby library into both,
- shut down cleanly.

If that crashes, Ruby::Box is not yet safe enough for the target design.

RubyGems/Bundler upstream cannot solve this layer.

## Implementation focus for the crash fix

The exact root cause is not proven yet, so the plan should stay evidence-based:

### Areas most worth inspecting

#### 1. Per-box class-extension lifetime and cleanup

Bundler loads a large amount of Ruby code and mutates many classes/modules.

That means a lot of per-box class extensions are created.

The most likely area is the machinery around:

- `rb_class_duplicate_classext`
- `rb_class_set_box_classext`
- `rb_class_unlink_classext`
- `rb_class_classext_free`
- `box->classext_cow_classes`

in `ruby/class.c` and `ruby/internal/class.h`.

#### 2. Box teardown in `box.c`

Because boxes track:

- `loading_table`
- `ruby_dln_libmap`
- `gvar_tbl`
- `classext_cow_classes`

any double-free or use-after-free during box cleanup can surface late at process exit.

#### 3. Native-extension bookkeeping as a secondary suspect

Bundler itself is mostly Ruby, but loading it also pulls in support libraries such as `monitor`, and boxed loading has native-extension-specific code paths.

So it is also worth checking:

- `ruby_dln_libmap`
- local-extension cleanup
- extension-handle ownership assumptions across boxes

This is a weaker hypothesis than class-extension cleanup, but still worth keeping in view.

### What not to do while fixing the crash

Do **not** use the crash as justification to:

- redesign `Ruby::Box`,
- move RubyGems out of prelude,
- make `ENV` box-local,
- add a VM-level gem registry,
- change `require` semantics.

The crash fix should be surgical.

## Regression tests Ruby should gain

At minimum, Ruby should add a `Ruby::Box` regression test that proves:

1. two boxes can both `require "bundler"` without crashing on normal exit,
2. a process that does so exits successfully,
3. the test uses ordinary exit, not `exit!`.

The best home is `ruby/test/ruby/test_box.rb` or a closely related box-specific test file.

## What Ruby should explicitly avoid changing

These changes are tempting, but not justified yet.

### Do not move `ruby_init_prelude()` after main-box creation

Yes, RubyGems being preloaded in the root box is part of why boxed gem isolation is tricky.

But changing Ruby boot order would be a very wide semantic change with unclear fallout.

Current evidence does not show that it is necessary.

### Do not add a new VM-level per-box gem registry

Ruby already provides per-box load state and per-box definition state.

RubyGems can build on that itself. Ruby should not absorb RubyGems policy into the VM.

### Do not add box-local `ENV`

Bundler uses environment variables, and that is awkward. But `ENV` is process-global by nature, and changing that would be much larger than the actual activation-isolation problem.

### Do not add new public APIs just to avoid Carton's current caller-side import resolution

Carton now resolves imports in the caller box and only carries the matched load-path entry when a name-based import needs that feature root. That is still consistent with the current box model.

Changing that model would be broader than the current need.

## Contingency only if RubyGems-only isolation fails

There is one possible fallback area, but it should stay explicitly out of scope unless the RubyGems prototype proves it necessary.

Ruby's own `doc/language/box.md` warns:

> Defined methods in a box may not be referred by built-in methods written in Ruby.

If that limitation ultimately prevents RubyGems from installing a stable boxed runtime view from Ruby code alone, then Ruby may need a small semantic improvement around how root-defined Ruby methods interact with box-local redefinitions/state.

But current evidence is **not** there yet, because:

- box-local redefinition of RubyGems singleton methods already improved isolation in probes,
- which suggests RubyGems likely can solve the main problem in user space.

So this is a contingency, not part of the current upstream plan.

## Acceptance criteria for Ruby upstream work

Ruby-side upstream work is complete when all of these are true:

1. two boxes can both require Bundler without crashing on normal exit,
2. no new Ruby public API was needed to get there,
3. the RubyGems/Bundler boxed-runtime prototype can run on top of existing box semantics,
4. existing non-box Ruby behavior stays unchanged.

## Recommended stance

If this gets discussed upstream, the message should be:

> Ruby already provides most of the right box semantics. We are not asking for new gem APIs in core. We are asking for one concrete `Ruby::Box` correctness fix so RubyGems/Bundler can safely build boxed activation isolation on top of the runtime that already exists.

That keeps the Ruby ask narrow and defensible.
