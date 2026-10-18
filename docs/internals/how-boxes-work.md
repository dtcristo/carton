# How `Ruby::Box` works

This guide is based on direct reading of the upstream Ruby source tree,
especially:

- `ruby/box.c`
- `ruby/internal/box.h`
- `ruby/load.c`
- `ruby/vm.c`
- `ruby/variable.c`
- `ruby/internal/class.h`
- `ruby/class.c`
- `ruby/doc/language/box.md`
- `ruby/test/ruby/test_box.rb`

It describes Ruby 4.0.7. The Master Box model dates from 4.0.6, and
[root-box-vs-main-box.md](root-box-vs-main-box.md) has the tagged sources and
the 4.0.5 split.

## What `Ruby::Box` is trying to do

`Ruby::Box` gives Ruby multiple in-process "worlds" for user code.

Each world can have its own:

- top-level constants
- top-level methods
- many global variables
- `$LOAD_PATH`
- `$LOADED_FEATURES`
- monkey patches to builtin classes/modules

without paying the cost of a subprocess for every isolated unit.

The idea is not "clone the whole VM". The idea is closer to:

> keep Ruby's core objects and VM, but make the pieces that define code visibility and lookup become box-specific.

That distinction explains both the power of Boxes and their sharp edges.

## Public API

`Ruby::Box` is a subclass of `Module`, and Box instances behave like namespaces.

### Class methods

| API | Meaning |
| --- | --- |
| `Ruby::Box.enabled?` | whether the process was started with `RUBY_BOX=1` |
| `Ruby::Box.current` | current Box for the running code |
| `Ruby::Box.root` | the Root Box created during Ruby bootstrap |
| `Ruby::Box.main` | the main user Box where the top-level script runs |

### Instance methods

| API | Meaning |
| --- | --- |
| `Ruby::Box.new` | create a new optional user Box |
| `box.require(feature)` | require a feature inside that Box |
| `box.require_relative(feature)` | require relative to the caller inside that Box |
| `box.load(path, wrap = false)` | load a file inside that Box |
| `box.eval(code)` | eval a string inside that Box |
| `box.load_path` | the Box's local load path array |
| `box.root?` | whether this is the Root Box |
| `box.main?` | whether this is the main user Box |
| `box.inspect` | debug-friendly identity like `#<Ruby::Box:2,user,optional>` |

### Minimum usage model

```ruby
box = Ruby::Box.new
box.require_relative("feature")

box::MyClass
box::MY_CONST
```

The Box object is how code defined in the Box is reached from the outside.

## The four Box roles

Ruby 4.0.7 distinguishes these roles:

| Box role | What it is |
| --- | --- |
| Master Box | internal template every Box is copied from; Ruby's docs say no code runs there |
| Root Box | runs Ruby bootstrap and builtin code |
| Main Box | user Box that runs the command-line program and `-r` loads |
| optional Box | extra user Box created by `Ruby::Box.new` |

Main and optional Boxes are both user Boxes. Carton runs each imported Carton
inside an optional Box; the application that imports them runs in Main.

## Boot sequence and the Master Box

Ruby initializes Root and Main from Master before prelude loading. Root,
Main, and later optional Boxes all start from Master rather than copying one
another.

Prelude helpers such as RubyGems are then loaded into each user Box's own
environment. A new optional Box therefore does not inherit application state
from Main or bootstrap mutations from Root.

This makes Box contents independent of creation time and prevents Root from
acting as a mutable template for later Boxes.

### The Master Box on Ruby 4.0.7

Ruby exposes it as `Ruby::Box.master` and `Ruby::Box#master?`. Its docs say
"no code runs in the master box", and Ruby's tests only read from it. On
4.0.7, though, code can run there and later Boxes inherit it:

- `Ruby::Box.master.eval`/`require` defines constants and monkey patches that
  every Box created afterwards sees. Main and existing Boxes are not
  shielded either: they may or may not see a later Master patch to a builtin
  class, depending on whether Ruby has already copied that class's state for
  them. That copy happens when a Box changes the class, but also on ordinary
  method calls, since the state includes mutable caches (see
  [Ruby's Box docs](https://docs.ruby-lang.org/en/4.0/Ruby/Box.html#class-Ruby::Box-label-Separate+cc_tbl+and+callable_m_tbl-2C+cvc_tbl+for+less+classext+CoW)).
  Calling `Rational(1, 2).numerator` in a Box is enough for it to stop
  seeing Master's later `Rational` patches.
- Master's `load_path` is copied into later Boxes.
- Objects and modules defined there are shared, not copied: a mutable
  constant or a module's instance variables changed in one Box are seen in
  every other.
- Monkey patches a Box adds to builtins such as `String` stay in that Box.
- Classes defined this way are not boxable, unlike builtins. Like classes
  defined in a user Box, they have one shared definition: reopening one in
  any Box, with `class` or `class_eval`, changes it in Master and every other
  Box. This holds for both `eval` and `require` into Master.
- Methods defined in Master run in Master, so their constant lookups and lazy
  `require`s use Master's `Object` and load path, not the caller's.

Loading all of Active Support's core extensions into Master once made them
available in every later Box at no per-Box cost; requiring them in each Box
instead cost about 830ms per Box. [examples/master_prelude](../../examples/master_prelude/README.md)
uses this as an optional, unsupported prelude. Carton itself does not, and
will not until Ruby supports template Boxes.

## The actual Box data structure

The implementation lives in `ruby/internal/box.h`.

`rb_box_t` contains:

- `box_object`
- `box_id`
- `top_self`
- `load_path`
- `load_path_snapshot`
- `load_path_check_cache`
- `expanded_load_path`
- `loaded_features`
- `loaded_features_snapshot`
- `loaded_features_realpaths`
- `loaded_features_realpath_map`
- `loaded_features_index`
- `loading_table`
- `ruby_dln_libmap`
- `gvar_tbl`
- `classext_cow_classes`
- `is_user`
- `is_optional`

This tells you what `Ruby::Box` really isolates:

1. file loading state,
2. many global-variable values,
3. class/module extension state,
4. native-extension handle bookkeeping.

It does **not** imply a brand new VM or brand new copies of every object.

## How a new Box is created

`box_entry_initialize` in `ruby/box.c` is the key constructor for Boxes.

It duplicates Master Box state:

- `rb_ary_dup(master->load_path)`
- `rb_ary_dup(master->loaded_features)`
- `rb_hash_dup(master->loaded_features_realpaths)`
- new empty `loading_table`
- new empty `gvar_tbl`
- new empty `classext_cow_classes`

Two consequences matter a lot:

### 1. New Boxes are copied from Master, not from the caller

This is why a Box created deep inside another Box does **not** automatically inherit the caller's custom `$LOAD_PATH`.

Carton handles that by carrying forward only the caller load-path entry that
resolved the imported feature.

### 2. Root and Main state are not inherited

Mutating `$LOAD_PATH` or loading application code in Root or Main does not
change the Master template used by a later optional Box. Any state Carton wants
to carry across the boundary must be propagated explicitly.

This includes `Ruby::Box.root.eval`: on 4.0.7, a constant or monkey patch
defined there is not visible in a Box created afterwards. Loading a framework
such as Rails into Root so every Box inherits it, which worked before the Master
Box in 4.0.6, no longer does. See [examples/rails_in_main](../../examples/rails_in_main/README.md).

## `current box` vs `loading box`

This is one of the easiest parts to miss.

The relevant code is in `ruby/vm.c`.

Ruby keeps both:

- the **current Box**: where the current execution context lives,
- the **loading Box**: which Box a `require`/`load` should resolve against.

`rb_vm_current_box` answers the first.

`rb_vm_loading_box` answers the second by walking control frames and looking for `VM_FRAME_FLAG_BOX_REQUIRE`.

That matters because `require` is not just "use whatever box I happen to be in right now". It is:

> find the box that initiated this loading operation, then use that box's load state.

This is why `box.require(...)` and nested requires remain coherent inside the Box.

## How `box.require` works

The `Ruby::Box` instance methods in `ruby/box.c` are thin wrappers:

- `rb_box_require`
- `rb_box_require_relative`
- `rb_box_load`

They all do the same important thing first:

```c
rb_vm_frame_flag_set_box_require(GET_EC());
```

Then they call the normal require/load entrypoints.

That single frame flag is how `rb_vm_loading_box` knows this load should be anchored to the Box.

## How `$LOAD_PATH` and `$LOADED_FEATURES` become Box-local

The relevant code is in `ruby/load.c`.

Ruby defines:

- `load_path_getter` -> `rb_loading_box()->load_path`
- `get_LOADED_FEATURES` -> `rb_loading_box()->loaded_features`

and marks the globals as Box-ready:

- `rb_gvar_box_ready("$LOAD_PATH")`
- `rb_gvar_box_ready("$LOADED_FEATURES")`

So when Ruby code reads `$LOAD_PATH` during a boxed require, it is reading the loading Box's array.

This is not an app-level convention. It is how the runtime is wired.

`box.eval` does not set that flag. Code it runs reads and writes the loading
Box's `$LOAD_PATH`, which during a nested Import is the importing Carton's
Box, not `box`. Carton therefore activates gems in a new Box from a file it
`require`s there (`lib/carton/activate_gems.rb`); `Gem.add_to_load_path` and
Bundler's setup both write `$LOAD_PATH` and would otherwise update the
wrong Box.

## The full `require` path under Boxes

`require_internal` in `ruby/load.c` is the center of the loading pipeline.

The critical line is:

```c
const rb_box_t *box = rb_loading_box();
```

From there:

1. `search_required` resolves the feature,
2. `rb_feature_p` checks whether it is already loaded in that Box,
3. Ruby loads Ruby code or a native extension,
4. `rb_provide_feature(box, path)` records the feature in that Box's `loaded_features`.

So the Box-aware file-loading model is very real:

- feature lookup is Box-specific,
- feature deduplication is Box-specific,
- the loaded-feature index is Box-specific.

That is why two Boxes can load different versions of the same Ruby file tree, as long as the rest of the runtime above them cooperates.

## Why constants and monkey patches can differ per Box

This is the second major mechanism after load-state isolation.

`Ruby::Box` does **not** create separate `String`, `Array`, or `Object` objects for every Box.

Instead, builtin classes/modules share identity, but their mutable definition state is split using per-Box class extensions.

The relevant structures live in:

- `ruby/internal/class.h`
- `ruby/class.c`

Each class/module has a prime class-extension record plus optional per-Box copies.

The class-extension structure includes:

- method table
- constant table
- callable method table / call cache state
- class variable table
- fields backing class ivars and related data

The important helpers are:

- `RCLASS_EXT_READABLE`
- `RCLASS_EXT_WRITABLE`
- `rb_class_duplicate_classext`
- `rb_class_set_box_classext`

The model is copy-on-write:

1. Boxes initially read the prime definition state,
2. the first write in a Box duplicates the class-extension data,
3. later reads/writes in that Box use the Box's extension tables.

That is how this can be true at once:

- `String == box::String`
- monkey-patching `String` in a Box stays local to that Box

This is also why top-level constants and top-level methods can be Box-local even though `Object` itself is a builtin class.

### Which classes get per-Box copies (Ruby 4.0.7)

- **Only classes created while Master is the current Box.** `class_alloc`
  marks a class "boxable" only when `BOX_MASTER_P(rb_current_box())`
  ([class.c](https://github.com/ruby/ruby/blob/v4.0.7/class.c#L649-L700)). In practice that means builtins defined during
  bootstrap. Classes defined later through `Ruby::Box.master.eval` or
  `require` are not boxable; verified on 4.0.7.
- **Classes created in any user Box have only prime, and it is writable.**
  They are shared objects with one method table and one constant table, so
  reopening such a class from another Box changes it for every Box holding
  a reference. Patching `String` is Box-local; patching a class another
  Carton defined is not.
- **Reads fall through to prime until the first write.** A Box that never
  writes `Rational` keeps seeing Master's current `Rational`
  ([`RCLASS_EXT_READABLE_IN_BOX`](https://github.com/ruby/ruby/blob/v4.0.7/internal/class.h#L352-L370),
  [`RCLASS_EXT_WRITABLE_LOOKUP`](https://github.com/ruby/ruby/blob/v4.0.7/internal/class.h#L387-L410)). Each
  new Box's gem prelude writes to `String`, `Array`, and others, so those
  get an early per-Box copy, which can look like a snapshot.
- **Box creation itself copies only `load_path`, `loaded_features`, and
  `Object`'s constant table**
  ([`box_entry_initialize`](https://github.com/ruby/ruby/blob/v4.0.7/box.c#L157-L185),
  [`box_initialize`](https://github.com/ruby/ruby/blob/v4.0.7/box.c#L389-L427)). Master never copies-on-write; it
  reads and writes prime directly
  ([`initialize_master_box`](https://github.com/ruby/ruby/blob/v4.0.7/box.c#L876-L897)).

## Why a Box is also a namespace

`Ruby::Box` subclasses `Module`, and top-level constants defined in a Box become constants of `Object` in that Box.

Ruby then exposes them through the Box object:

```ruby
box::FOO
box::SomeClass
```

The Box's `top_self` also participates in top-level code execution.

So a Box is both:

- a runtime loading context,
- and the external namespace through which that context is observed.

## Global variables: Box-local, but only for actual Ruby globals

The relevant code is in `ruby/variable.c`.

`rb_gvar_set` and `rb_gvar_get` can store values in `box->gvar_tbl`.

Ruby also marks some globals as Box-ready with `rb_gvar_box_ready`.

This is why globals like:

- `$LOAD_PATH`
- `$LOADED_FEATURES`

can behave Box-locally.

But this does **not** mean every process-global thing in Ruby becomes Box-local.

The biggest counterexample is `ENV`.

Runtime probes confirmed that writing `ENV["X"]` inside a Box changes it for the whole process.

That is because `ENV` is not just another global variable backed by `gvar_tbl`. It is a process-level object with its own behavior.

This distinction matters a lot for Bundler.

## Native extensions: Boxes do extra work here

Native extensions are one of the most interesting parts of `Ruby::Box`.

When a Box loads a native extension, Ruby cannot safely pretend that one shared `.bundle` / `.so` file mapping is always enough.

`ruby/box.c` handles this through `rb_box_local_extension`.

It:

1. builds a unique filename using the Box id,
2. copies the original extension file to a Box-local temp filename,
3. loads that copied file,
4. tracks it in `ruby_dln_libmap`,
5. removes it during cleanup.

So boxed native-extension loading is not just logical isolation. Ruby is creating physically separate temporary extension files per Box.

This explains why Boxes can do things normal Ruby cannot easily do with one shared `dlopen` target.

It also explains why teardown and cleanup bugs in `Ruby::Box` can be subtle.

## Main Box owns the user program

Ruby creates Main from Master before prelude loading. The command-line
program and `-r` features run in Main, not Root. Root remains the environment
for bootstrap and builtin code.

This distinction is semantic, not merely boot ordering: Carton's top-level
application is hosted by Main, while imported Cartons run in optional Boxes.

## Known sharp edges from Ruby's own docs

`ruby/doc/language/box.md` calls out several important limitations.

The most relevant one for gem/runtime work is:

> Defined methods in a box may not be referred by built-in methods written in Ruby.

Ruby 4.0.5 RubyGems failures matched it. Boxed `Symbol#to_proc` and `super`
dispatch picked the wrong method. They do not reproduce on 4.0.6 or later, but
keep the warning in mind when a boxed library calls back into Ruby-written
builtins.

Other documented or visible rough edges include:

- experimental status warning,
- some top-level method behavior still being incomplete,
- incomplete guarantees around warnings and some other globally flavored facilities.

## Bundler in Boxes

Separate Boxes load separate `Bundler` modules, and per-Carton bundles,
conflicting versions, and app-bundle path gems stay out of Main Box. See
[how-gems-work.md](how-gems-work.md#ruby-407-confirmed-behavior) for details
and [upstream.md](upstream.md#resolved) for the 4.0.6 problems that 4.0.7
fixed.

## What this means for Carton

Carton is aligned with the parts of `Ruby::Box` that are already strong:

1. each Carton, an Entrypoint plus its directory, loads once into its own Box, and later imports share it,
2. `$LOAD_PATH` inside that Box is isolated,
3. top-level constants and builtin-class monkey patches defined in the imported Carton stay inside that Box; classes the Carton defines are shared objects, so another Box that reopens them changes them everywhere,
4. only the exported value or a `Carton::Namespace` leaves the Box; the Box itself never does.

But the internals also explain Carton's current constraints:

### Why Carton resolves imports in the caller Box first

Because new Boxes copy **Master**, not the current caller Box. Carton therefore asks the caller Box to resolve the feature name, then carries only the matched load-path entry into the imported Box when that feature needs its own load-path root.

### Why Bundler setup inside the Box is the right shape

Because `require` really does resolve against the loading Box's local `$LOAD_PATH` and `$LOADED_FEATURES`.

### Why `setup_bundle` manages `ENV`

RubyGems registry state is Box-local, but `ENV` is process-global. Bundler
reads its Gemfile from `ENV` and writes subprocess variables back to it.

### Subclassing a class from another Box

A Box can subclass a class object imported from another Box. The subclass's
own methods run in its Box; inherited methods run in the Box that defined
them, with that Box's constants and monkey patches. On 4.0.7 this is enough
to define Active Record models and Action Controller controllers in domain
Cartons while Rails loads once in a framework Carton
([examples/rails_in_cartons](../../examples/rails_in_cartons/README.md)). Lookups by
constant *name* inside the defining Box (Rails' `constantize`) still need the
subclass defined there too.

### Which Box runs an autoload

An autoload loads in the Box that registered it, whichever Box references the
constant first, so a Carton's lazy constants, Zeitwerk's included, load in the
Carton's Box. Carton relies on this, so `Carton::Box` wraps a plain
`Ruby::Box` rather than subclassing it.

On 4.0.7, Ruby loads the file with `Ruby::Box#require`, which skips the Box's
`Kernel#require` and so any patch on it, such as the one Zeitwerk uses to run
`on_load` callbacks and track files for reloading
([Bug #21830](https://bugs.ruby-lang.org/issues/21830)). Carton defines
`require` on each Box object to call `Kernel#require` inside the Box instead.
Ruby master calls the Box's own `require`
([PR #18534](https://github.com/ruby/ruby/pull/18534)), so the workaround can
go once Carton's minimum Ruby includes that fix.

### Why Carton should avoid unnecessary Ruby-core changes

Because most of the mechanics Carton wants are already present:

- Box-local load paths,
- Box-local loaded features,
- Box-local constant/method tables,
- Box-local Bundler constants when Bundler is first required in the Box.

Carton needs no upstream change today. [upstream.md](upstream.md) tracks the small open items.

## The short version

If you want one sentence that stays accurate:

> `Ruby::Box` already isolates file loading, RubyGems activation state, and
> monkey patches to builtins. Carton manages the process-global `ENV`, carries
> a gem Carton's dependencies into its Box, and leaves classes it defines
> shared.

That is the lens to keep while designing Carton.
