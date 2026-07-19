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

The canonical model is tagged Ruby 4.0.6 source. Historical runtime probes are
labelled Ruby 4.0.5 where they still await 4.0.6 reproduction.
See [root-box-vs-main-box.md](root-box-vs-main-box.md) for the tagged sources
and version split.

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

## The four box roles

Ruby 4.0.6 distinguishes these roles:

| Box role | What it is |
| --- | --- |
| Master Box | internal immutable template; no code runs there |
| Root Box | runs Ruby bootstrap and builtin code |
| Main Box | user Box that runs the command-line program and `-r` loads |
| optional Box | extra user Box created by `Ruby::Box.new` |

Main and optional Boxes are both user Boxes. Carton runs each imported Carton
inside an optional Box; the application that imports them runs in Main.

## Boot sequence and the Master Box

Ruby 4.0.6 initializes Root and Main from Master before prelude loading. Root,
Main, and later optional Boxes all start from Master rather than copying one
another.

Prelude helpers such as RubyGems are then loaded into each user Box's own
environment. A new optional Box therefore does not inherit application state
from Main or bootstrap mutations from Root.

This makes Box contents independent of creation time and prevents Root from
acting as a mutable template for later Boxes.

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

This is why a box created deep inside another box does **not** automatically inherit the caller's custom `$LOAD_PATH`.

Carton handles that by carrying forward only the caller load-path entry that
resolved the imported feature.

### 2. Root and Main state are not inherited

Mutating `$LOAD_PATH` or loading application code in Root or Main does not
change the Master template used by a later optional Box. Any state Carton wants
to carry across the boundary must be propagated explicitly.

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

## Main Box owns the user program

Ruby 4.0.6 creates Main from Master before prelude loading. The command-line
program and `-r` features run in Main, not Root. Root remains the environment
for bootstrap and builtin code.

This distinction is semantic, not merely boot ordering: Carton's top-level
application is hosted by Main, while imported Cartons run in optional Boxes.

## Known sharp edges from Ruby's own docs

`ruby/doc/language/box.md` calls out several important limitations.

The most relevant one for gem/runtime work is:

> Defined methods in a box may not be referred by built-in methods written in Ruby.

That warning is easy to underestimate, and it matched the Ruby 4.0.5
gem/runtime failures. Direct boxed method calls worked while dispatch through
`Symbol#to_proc` selected the wrong method, and boxed `super` selected the
wrong superclass implementation. Revalidate both on 4.0.6.

This limitation is a big part of why RubyGems-in-box is hard even though `$LOAD_PATH` is already isolated.

Other documented or visible rough edges include:

- experimental status warning,
- some top-level method behavior still being incomplete,
- incomplete guarantees around warnings and some other globally flavored facilities.

## Ruby 4.0.5 Bundler observations

Ruby 4.0.5 probes handled the basic multi-Box case:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler'")
box2.eval("require 'bundler'")
```

Both boxes load distinct `Bundler` modules and the process exits normally.
Conflicting non-path bundles also keep their activation state separate from
each other and Main Box.

Ruby 4.0.5 exposed three incomplete boundaries that require reproduction on
4.0.6:

- `RUBY_BOX=1 bundle exec` can evaluate a gemspec before
  `Gem::Specification` is visible,
- path-gem setup crosses method definitions loaded in different boxes,
- boxed dispatch through `Symbol#to_proc` and `super` can select the wrong
  method.

## What this means for Carton

Carton is aligned with the parts of `Ruby::Box` that are already strong:

1. each import gets a fresh box,
2. `$LOAD_PATH` inside that box is isolated,
3. constants and monkey patches defined in the imported carton stay inside that box,
4. the returned box or export object becomes the carton boundary.

But the internals also explain Carton's current constraints:

### Why Carton resolves imports in the caller box first

Because new Boxes copy **Master**, not the current caller Box. Carton therefore asks the caller Box to resolve the feature name, then carries only the matched load-path entry into the imported Box when that feature needs its own load-path root.

### Why `require "bundler/setup"` inside the box is the right shape

Because `require` really does resolve against the loading box's local `$LOAD_PATH` and `$LOADED_FEATURES`.

### Why that still is not enough for full Bundler support

RubyGems registry state is Box-local. The earlier startup and path-gem failures
crossed definitions loaded in different Box contexts; reproduce them on 4.0.6
before carrying that diagnosis forward.

### Why Carton should avoid unnecessary Ruby-core changes

Because most of the mechanics Carton wants are already present:

- box-local load paths,
- box-local loaded features,
- box-local constant/method tables,
- box-local Bundler constants when Bundler is first required in the box.

The next upstream checks are narrow:

1. reproduce the earlier failures on Ruby 4.0.6,
2. fix only any symbol-proc or `super` dispatch bugs that remain,
3. complete RubyGems/Bundler path-gem setup inside each Box,
4. verify `RUBY_BOX=1 bundle exec` under the 4.0.6 prelude model.

That is a much smaller upstream target than "rebuild gem loading around boxes from scratch".

## The short version

If you want one sentence that stays accurate:

> `Ruby::Box` already isolates file loading, RubyGems activation state, and most
> language definitions; remaining Bundler work must be established against the
> Ruby 4.0.6 Master-based model.

That is the lens to keep while designing Carton.
