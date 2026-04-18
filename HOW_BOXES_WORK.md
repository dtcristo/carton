# How `Ruby::Box` works

This guide is based on direct reading of the Ruby source tree at `/Users/dtcristo/Code/ruby/ruby`, especially:

- `ruby/box.c`
- `ruby/internal/box.h`
- `ruby/load.c`
- `ruby/vm.c`
- `ruby/variable.c`
- `ruby/internal/class.h`
- `ruby/class.c`
- `ruby/doc/language/box.md`
- `ruby/test/ruby/test_box.rb`

It also includes runtime probes run against Ruby `4.0.2` with `RUBY_BOX=1`.

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

That distinction explains both the power of boxes and their sharp edges.

## Public API

`Ruby::Box` is a subclass of `Module`, and box instances behave like namespaces.

### Class methods

| API | Meaning |
| --- | --- |
| `Ruby::Box.enabled?` | whether the process was started with `RUBY_BOX=1` |
| `Ruby::Box.current` | current box for the running code |
| `Ruby::Box.root` | the root box created during Ruby bootstrap |
| `Ruby::Box.main` | the main user box where the top-level script runs |

### Instance methods

| API | Meaning |
| --- | --- |
| `Ruby::Box.new` | create a new optional user box |
| `box.require(feature)` | require a feature inside that box |
| `box.require_relative(feature)` | require relative to the caller inside that box |
| `box.load(path, wrap = false)` | load a file inside that box |
| `box.eval(code)` | eval a string inside that box |
| `box.load_path` | the box's local load path array |
| `box.root?` | whether this is the root box |
| `box.main?` | whether this is the main user box |
| `box.inspect` | debug-friendly identity like `#<Ruby::Box:2,user,optional>` |

### Minimum usage model

```ruby
box = Ruby::Box.new
box.require_relative("feature")

box::MyClass
box::MY_CONST
```

The box object is how code defined in the box is reached from the outside.

## The three box kinds

Ruby's own docs and `box.c` make an important distinction:

| Box kind | What it is |
| --- | --- |
| root box | created during Ruby bootstrap |
| main box | the user box that runs the main script |
| optional box | every extra `Ruby::Box.new` box |

The root box is special:

- Ruby bootstrap runs there,
- builtin classes/modules are originally defined there,
- RubyGems is loaded there during prelude,
- new user boxes are copied from it.

The main box is also special:

- it is created automatically after prelude,
- it is the default user world,
- top-level user code runs there.

Every later `Ruby::Box.new` is an optional user box.

## Boot sequence: the root box matters more than you think

The startup ordering in `ruby/ruby.c` is the first key fact:

1. initialize Ruby runtime,
2. run `ruby_init_prelude()`,
3. only then call `rb_initialize_main_box()`.

That means code loaded during prelude becomes part of root-box state before the main user box exists.

`ruby/gem_prelude.rb` is especially important because it loads RubyGems:

```ruby
require "rubygems"
require "bundled_gems"
```

So when the main box and later user boxes are created, they are created from a root box that already knows about RubyGems.

This is the single most important `Ruby::Box` fact for Carton's gem story.

## The actual box data structure

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

## How a new box is created

`box_entry_initialize` in `ruby/box.c` is the key constructor for user boxes.

It duplicates root-box state:

- `rb_ary_dup(root->load_path)`
- `rb_ary_dup(root->loaded_features)`
- `rb_hash_dup(root->loaded_features_realpaths)`
- new empty `loading_table`
- new empty `gvar_tbl`
- new empty `classext_cow_classes`

Two consequences matter a lot:

### 1. New boxes are copied from the root box, not from the caller

This is why a box created deep inside another box does **not** automatically inherit the caller's custom `$LOAD_PATH`.

Carton works around that by manually copying forward only the non-gem parent paths it wants to preserve.

### 2. A box starts with whatever the root box had already loaded

That includes prelude-loaded libraries such as RubyGems.

So a fresh box is not "blank". It is "root snapshot plus per-box copy-on-write state".

## `current box` vs `loading box`

This is one of the easiest parts to miss.

The relevant code is in `ruby/vm.c`.

Ruby keeps both:

- the **current box**: where the current execution context lives,
- the **loading box**: which box a `require`/`load` should resolve against.

`rb_vm_current_box` answers the first.

`rb_vm_loading_box` answers the second by walking control frames and looking for `VM_FRAME_FLAG_BOX_REQUIRE`.

That matters because `require` is not just "use whatever box I happen to be in right now". It is:

> find the box that initiated this loading operation, then use that box's load state.

This is why `box.require(...)` and nested requires remain coherent inside the box.

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

That single frame flag is how `rb_vm_loading_box` knows this load should be anchored to the box.

## How `$LOAD_PATH` and `$LOADED_FEATURES` become box-local

The relevant code is in `ruby/load.c`.

Ruby defines:

- `load_path_getter` -> `rb_loading_box()->load_path`
- `get_LOADED_FEATURES` -> `rb_loading_box()->loaded_features`

and marks the globals as box-ready:

- `rb_gvar_box_ready("$LOAD_PATH")`
- `rb_gvar_box_ready("$LOADED_FEATURES")`

So when Ruby code reads `$LOAD_PATH` during a boxed require, it is reading the loading box's array.

This is not an app-level convention. It is how the runtime is wired.

## The full `require` path under boxes

`require_internal` in `ruby/load.c` is the center of the loading pipeline.

The critical line is:

```c
const rb_box_t *box = rb_loading_box();
```

From there:

1. `search_required` resolves the feature,
2. `rb_feature_p` checks whether it is already loaded in that box,
3. Ruby loads Ruby code or a native extension,
4. `rb_provide_feature(box, path)` records the feature in that box's `loaded_features`.

So the box-aware file-loading model is very real:

- feature lookup is box-specific,
- feature deduplication is box-specific,
- the loaded-feature index is box-specific.

That is why two boxes can load different versions of the same Ruby file tree, as long as the rest of the runtime above them cooperates.

## Why constants and monkey patches can differ per box

This is the second major mechanism after load-state isolation.

`Ruby::Box` does **not** create separate `String`, `Array`, or `Object` objects for every box.

Instead, builtin classes/modules share identity, but their mutable definition state is split using per-box class extensions.

The relevant structures live in:

- `ruby/internal/class.h`
- `ruby/class.c`

Each class/module has a prime class-extension record plus optional per-box copies.

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

1. boxes initially read the prime/root definition state,
2. the first write in a box duplicates the class-extension data,
3. later reads/writes in that box use the box's extension tables.

That is how this can be true at once:

- `String == box::String`
- monkey-patching `String` in a box stays local to that box

This is also why top-level constants and top-level methods can be box-local even though `Object` itself is a builtin class.

## Why a box is also a namespace

`Ruby::Box` subclasses `Module`, and top-level constants defined in a box become constants of `Object` in that box.

Ruby then exposes them through the box object:

```ruby
box::FOO
box::SomeClass
```

The box's `top_self` also participates in top-level code execution.

So a box is both:

- a runtime loading context,
- and the external namespace through which that context is observed.

## Global variables: box-local, but only for actual Ruby globals

The relevant code is in `ruby/variable.c`.

`rb_gvar_set` and `rb_gvar_get` can store values in `box->gvar_tbl`.

Ruby also marks some globals as box-ready with `rb_gvar_box_ready`.

This is why globals like:

- `$LOAD_PATH`
- `$LOADED_FEATURES`

can behave box-locally.

But this does **not** mean every process-global thing in Ruby becomes box-local.

The biggest counterexample is `ENV`.

Runtime probes confirmed that writing `ENV["X"]` inside a box changes it for the whole process.

That is because `ENV` is not just another global variable backed by `gvar_tbl`. It is a process-level object with its own behavior.

This distinction matters a lot for Bundler.

## Native extensions: boxes do extra work here

Native extensions are one of the most interesting parts of `Ruby::Box`.

When a box loads a native extension, Ruby cannot safely pretend that one shared `.bundle` / `.so` file mapping is always enough.

`ruby/box.c` handles this through `rb_box_local_extension`.

It:

1. builds a unique filename using the box id,
2. copies the original extension file to a box-local temp filename,
3. loads that copied file,
4. tracks it in `ruby_dln_libmap`,
5. removes it during cleanup.

So boxed native-extension loading is not just logical isolation. Ruby is creating physically separate temporary extension files per box.

This explains why boxes can do things normal Ruby cannot easily do with one shared `dlopen` target.

It also explains why teardown and cleanup bugs in `Ruby::Box` can be subtle.

## The main box is created late on purpose

`rb_initialize_main_box` in `ruby/box.c` creates the main user box after prelude.

It also eagerly creates a writable class-extension for `Object` in the main box:

```c
RCLASS_EXT_WRITABLE_IN_BOX(rb_cObject, box);
```

The comment says this finalizes the set of visible top-level constants.

That is a good clue about how much of `Ruby::Box` is really about "what `Object` means in this box" rather than just file loading.

## Known sharp edges from Ruby's own docs

`ruby/doc/language/box.md` calls out several important limitations.

The most relevant one for gem/runtime work is:

> Defined methods in a box may not be referred by built-in methods written in Ruby.

That warning is easy to underestimate, but it matches what the gem/runtime probes found:

- methods loaded in the root box do not automatically become a fresh box-local API surface,
- simply changing box-local instance variables is sometimes not enough,
- reopening or redefining methods inside the box can change the behavior back to being box-local.

This limitation is a big part of why RubyGems-in-box is hard even though `$LOAD_PATH` is already isolated.

Other documented or visible rough edges include:

- experimental status warning,
- some top-level method behavior still being incomplete,
- incomplete guarantees around warnings and some other globally flavored facilities.

## Observed Bundler edge under boxes

One runtime probe was especially important:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler'")
box2.eval("require 'bundler'")
```

On Ruby `4.0.2`, that succeeds during execution but crashes on normal process exit with a malloc/free abort.

Important details:

- requiring Bundler in only one box did **not** crash,
- forcing `Process.exit!(0)` avoided teardown and preserved expected per-box behavior,
- the crash happened even before trying conflicting Gemfiles.

So there is a real `Ruby::Box` teardown/cleanup issue around multi-box Bundler loading.

For Carton's goals, that makes this a Ruby runtime problem, not merely a Bundler API annoyance.

## What this means for Carton

Carton is aligned with the parts of `Ruby::Box` that are already strong:

1. each import gets a fresh box,
2. `$LOAD_PATH` inside that box is isolated,
3. constants and monkey patches defined in the imported carton stay inside that box,
4. the returned box or export object becomes the carton boundary.

But the internals also explain Carton's current constraints:

### Why Carton forwards parent load paths manually

Because new boxes copy the **root** box, not the current caller box.

### Why `require "bundler/setup"` inside the box is the right shape

Because `require` really does resolve against the loading box's local `$LOAD_PATH` and `$LOADED_FEATURES`.

### Why that still is not enough for full gem isolation

Because RubyGems was loaded in the root box during prelude, and some of its runtime methods and registries are not automatically fresh per box.

### Why Carton should avoid unnecessary Ruby-core changes

Because most of the mechanics Carton wants are already present:

- box-local load paths,
- box-local loaded features,
- box-local constant/method tables,
- box-local Bundler constants when Bundler is first required in the box.

The real remaining blockers are narrower:

1. RubyGems/Bundler need a supported way to make their mutable registry state box-local.
2. Ruby itself needs its multi-box Bundler teardown bug fixed.

That is a much smaller upstream target than "rebuild gem loading around boxes from scratch".

## The short version

If you want one sentence that stays accurate:

> `Ruby::Box` already isolates file loading and most language-level definitions by attaching them to a per-box runtime record and per-box class extensions; the hard part is everything above that layer which was already loaded into the root box and still behaves like shared Ruby code.

That is the lens to keep while designing Carton.
