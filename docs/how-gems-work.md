# How Ruby gems, RubyGems, Bundler, and `Ruby::Box` fit together

This guide is based on direct reading of the upstream Ruby, RubyGems, and
Bundler source trees.

The canonical Box model is tagged Ruby 4.0.6 source. Historical runtime probes
are labelled Ruby 4.0.5 where they still await 4.0.6 reproduction.

The guide has two layers:

1. **Layer 1** gives a medium-complexity mental model.
2. **Layer 2** walks the actual implementation in Ruby core, RubyGems, and Bundler.

## Layer 1: the medium-complexity model

### Start with plain Ruby

Before RubyGems or Bundler enter the picture, Ruby has two core pieces of state for `require`:

| Thing | What it means |
| --- | --- |
| `$LOAD_PATH` | Directories Ruby searches when you `require "foo"` |
| `$LOADED_FEATURES` | Concrete files Ruby already loaded, so the same feature is not loaded twice |

The flow is:

1. Ruby gets a requested feature such as `"json"` or `"my_app/models/user"`.
2. It searches `$LOAD_PATH` for matching files like `json.rb` or `json.bundle`.
3. If it finds one and that file is not already represented in `$LOADED_FEATURES`, Ruby loads it.
4. Ruby then records the loaded file in `$LOADED_FEATURES`.

That is the whole mechanism at the Ruby core level.

### What RubyGems adds

RubyGems does **not** replace Ruby's loader with a completely different one. It hooks into `Kernel#require` and `Kernel#gem` so it can activate installed gems on demand.

The important idea is **activation**.

An **activated gem** is a gem version RubyGems has selected for the current process and added to runtime state. Activation usually means:

1. pick a gem version,
2. activate its dependencies,
3. add the gem's `require_paths` to `$LOAD_PATH`,
4. register the spec in `Gem.loaded_specs`.

That is different from actually requiring a file from the gem.

| State | Meaning |
| --- | --- |
| gem installed | Files exist on disk |
| gem activated | RubyGems selected the spec and updated runtime state |
| file required | A concrete `.rb` or native extension file was actually loaded |

So this is normal and important:

- `Bundler.setup` can activate many gems without putting any of their files into `$LOADED_FEATURES`.
- `Kernel#gem "rake"` can activate `rake` without requiring `rake.rb`.
- `$LOADED_FEATURES` answers "which files ran?", not "which gems are active?"

### What `Kernel#gem` does

`Kernel#gem` is RubyGems' explicit activation API.

```ruby
gem "rake", "~> 13.0"
require "rake"
```

That says: pick a compatible `rake` spec first, then require files against the resulting load path.

If a different incompatible version was already activated, `gem` raises.

### What Bundler adds

Bundler sits one level above RubyGems.

RubyGems by itself answers:

> "Given the installed gems on this machine, what gem should satisfy this `require` or `gem` call?"

Bundler answers:

> "Ignore the machine-wide set. Only these specs from this Gemfile/lockfile are allowed."

In practice:

- `require "bundler"` loads the Bundler library.
- `require "bundler/setup"` runs `Bundler.setup`.
- `Bundler.setup` computes the bundle, rewrites some RubyGems entrypoints, marks the chosen specs as loaded, and adds their load paths.
- `Bundler.require` then actually requires the default entry files for gems in the selected groups.

So Bundler does not replace Ruby's loader either. It narrows and rewires RubyGems so later `require` calls see a bundle-shaped world.

### How activation, `$LOAD_PATH`, and `$LOADED_FEATURES` relate

This is the simplest accurate mental model:

| Mechanism | Main job |
| --- | --- |
| Ruby core `require` | Search paths, load files, remember loaded files |
| RubyGems activation | Pick gem specs and add gem `lib` dirs to `$LOAD_PATH` |
| Bundler setup | Preselect which specs are allowed, then patch RubyGems to that view |

Or in one sentence:

> **Ruby loads files, RubyGems activates gem versions, Bundler constrains which versions may activate.**

### What changes under `Ruby::Box`

`Ruby::Box` makes key Ruby runtime structures box-local, especially:

- `$LOAD_PATH`
- `$LOADED_FEATURES`
- global variables that Ruby marks box-ready
- class/module constant tables and method tables through class-extension copy-on-write

That means file loading itself is already much more isolated than normal Ruby.

RubyGems and Bundler are mostly Ruby code running on top of that runtime, so
their behavior also depends on Ruby method lookup across boxes.

The most important Ruby 4.0.6 facts are:

1. **Master Box is the immutable source copied into Root, Main, and optional Boxes.**
2. **Root runs bootstrap/builtins; Main runs the application.**
3. **Prelude helpers such as RubyGems are loaded into user Boxes independently.**
4. Therefore `require "rubygems"` is already satisfied in a fresh optional Box without inheriting Main or Root state.
5. **Bundler is not preloaded that way.** If the first `require "bundler"` happens inside a Box, that Box gets its own `Bundler` constant and module state.
6. RubyGems definitions and activation state belong to each user Box.
7. Earlier Bundler startup, path-gem, and method-dispatch failures must be reproduced on 4.0.6 before their diagnoses are treated as current.

That is why requiring `bundler/setup` inside each Carton remains the right isolation shape, subject to 4.0.6 verification.

### Ruby 4.0.5 findings awaiting revalidation

The Ruby 4.0.5 findings were:

- `$LOAD_PATH`, `Gem.loaded_specs`, and `Gem::Specification` registry changes
  can stay box-local.
- `Bundler` module state can be box-local if Bundler is first loaded inside the
  box.
- conflicting non-path bundles work in separate boxes, including under an
  already-bundled Main Box.
- path gems crossed unsupported boxed method-dispatch paths.

Reproduce these findings on Ruby 4.0.6 before treating them as current limits.

That is why Carton's current per-Carton Bundler pattern is:

```ruby
# cartons/my_carton/lib/my_carton.rb
Carton.bootstrap_rubygems!
Carton.with_bundle { require "bundler/setup" }
```

Carton still carries this compatibility bootstrap, although Ruby 4.0.5 probes
showed no need for a broad RubyGems registry split for conflicting non-path bundles.

At the top-level app boundary, `Carton.with_bundle { require "bundler/setup" }`
also patches RubyGems' path-gem load-path lookup in the current Box. Path-gem
setup was incomplete on Ruby 4.0.5, so this remains compatibility code pending
4.0.6 verification.

### What applications generally should touch

For most applications:

| API | Normal use |
| --- | --- |
| `require` | load files |
| `gem` | rarely; explicit version activation without Bundler |
| `Bundler.setup` / `require "bundler/setup"` | activate the bundle early |
| `Bundler.require` | optional convenience for requiring gem entry files |

For more advanced embedding/runtime work:

| API | When it matters |
| --- | --- |
| `Gem.loaded_specs` | observe what RubyGems considers activated |
| `Gem::Specification` APIs | inspect or reset gem spec state |
| `Gem.use_paths` / `Gem.clear_paths` | rebuild RubyGems path state |
| `Bundler.reset!` | reset Bundler's own cached objects, not a full multi-bundle isolation mechanism |
| `Bundler.with_unbundled_env` | subprocess handoff, shelling out, or escaping the current bundle |

If you are doing complex gem runtime work, the two most important warnings are:

1. **Activated gems are not the same thing as required files.**
2. **Bundler isolation is more than `$LOAD_PATH`; it also depends on RubyGems registry state.**

## Layer 2: the implementation walk

## 1. Ruby core: where `require` really gets its state

The key file is `ruby/load.c`.

Ruby wires `$LOAD_PATH` and `$LOADED_FEATURES` through box-aware getters:

- `load_path_getter` returns `rb_loading_box()->load_path`
- `get_LOADED_FEATURES` returns `rb_loading_box()->loaded_features`
- `rb_gvar_box_ready("$LOAD_PATH")`
- `rb_gvar_box_ready("$LOADED_FEATURES")`

That is the first crucial point: **load state is attached to the loading box, not just to the current lexical context.**

The actual `require` path is:

1. `require_internal` in `ruby/load.c`
2. `search_required`
3. `rb_feature_p`
4. `load_iseq_eval` or `load_ext`
5. `rb_provide_feature`

`require_internal` explicitly captures:

```c
const rb_box_t *box = rb_loading_box();
```

and then uses that box for feature lookup and feature registration.

So from Ruby core's point of view, the important state is already box-local:

- load path
- loaded features
- feature index
- loading table
- extension handle map

## 2. `Ruby::Box`: what a box actually contains

The key structure is `rb_box_t` in `ruby/internal/box.h`.

Each box carries its own:

- `load_path`
- `expanded_load_path`
- `loaded_features`
- `loaded_features_index`
- `loading_table`
- `ruby_dln_libmap`
- `gvar_tbl`
- `classext_cow_classes`

In Ruby 4.0.6, `box_entry_initialize` creates each Box by duplicating state from the immutable **Master Box**:

- `box->load_path = rb_ary_dup(master->load_path)`
- `box->loaded_features = rb_ary_dup(master->loaded_features)`
- `box->loaded_features_realpaths = rb_hash_dup(master->loaded_features_realpaths)`

That means a new Box does **not** start from the caller, Main, or Root. It starts from Master.

This is why Carton resolves feature names in the caller box and only carries the matching load-path entry into the imported box when that feature root is needed.

## 3. Ruby boot order: why RubyGems is local to each user Box

The key files are:

- `ruby/ruby.c`
- `ruby/gem_prelude.rb`

Ruby 4.0.6 initializes Root and Main from Master before prelude loading. Its gem prelude does:

```ruby
require "rubygems"
require "bundled_gems"
```

if `Gem` is defined.

Ruby loads these prelude helpers into Main and optional user Boxes independently.
Thus `require "rubygems"` is already satisfied in each user Box, but not because
its `$LOADED_FEATURES` was copied from Root. RubyGems definitions and activation
state belong to that Box's environment.

## 4. RubyGems: activation is spec selection plus load-path mutation

The core RubyGems files are:

- `rubygems/lib/rubygems.rb`
- `rubygems/lib/rubygems/specification.rb`
- `rubygems/lib/rubygems/specification_record.rb`
- `rubygems/lib/rubygems/core_ext/kernel_require.rb`
- `rubygems/lib/rubygems/core_ext/kernel_gem.rb`

### `Kernel#require`

When RubyGems is loaded, `rubygems/core_ext/kernel_require.rb` aliases Ruby's original `require` to `gem_original_require`, then replaces `Kernel#require`.

That replacement does three main things:

1. If Ruby can already load the file from the current load path, let Ruby do that.
2. If the feature belongs to a default gem, activate that gem first.
3. Otherwise look through unresolved gem dependencies or try to auto-activate an installed gem containing the feature.

Important calls in that file:

- `Gem.find_default_spec(path)`
- `Kernel.send(:gem, name, ...)`
- `Gem::Specification.find_active_stub_by_path(path)`
- `Gem::Specification.find_in_unresolved(path)`
- `Gem.try_activate(path)`

So RubyGems activation is tightly interleaved with `require`.

### `Kernel#gem`

`rubygems/core_ext/kernel_gem.rb` implements explicit activation.

The important steps are:

1. build a `Gem::Dependency`,
2. check `Gem.loaded_specs[gem_name]`,
3. resolve a matching spec,
4. call `spec.activate`.

### `Gem::Specification#activate`

This is the center of "activated gems".

In `rubygems/specification.rb`, `activate` does:

1. check whether another spec of the same name is already in `Gem.loaded_specs`,
2. check conflicts,
3. `activate_dependencies`,
4. `add_self_to_load_path`,
5. `Gem.loaded_specs[name] = self`,
6. mark `@activated` and `@loaded`.

`add_self_to_load_path` calls:

```ruby
Gem.add_to_load_path(*full_require_paths)
```

and `Gem.add_to_load_path` in `rubygems.rb` does:

```ruby
@activated_gem_paths = activated_gem_paths + paths.size
$LOAD_PATH.insert(Gem.load_path_insert_index, *paths)
```

So the essential RubyGems activation outputs are:

- an entry in `Gem.loaded_specs`
- one or more inserted gem `lib` directories in `$LOAD_PATH`

Again: **that is still not the same thing as requiring files from the gem.**

### `Gem.loaded_specs`

`Gem.loaded_specs` is declared in `rubygems.rb` as an `attr_reader`, backed by:

```ruby
@loaded_specs = {}
```

This is the main runtime registry for activated gems.

If you only remember one RubyGems structure, remember this one.

### `Gem::Specification` registries

`Gem::Specification` also keeps global-ish registry state:

- `.specification_record`
- `.all`
- `.all=`
- `.reset`
- `.unresolved_deps`
- `.dirs=`
- many query methods that delegate to `specification_record`

These matter because Bundler does not merely set `Gem.loaded_specs`. It also narrows RubyGems' whole view of installed specs.

## 5. Bundler: it rewrites RubyGems' view of the world

The key Bundler files are:

- `rubygems/bundler/lib/bundler.rb`
- `rubygems/bundler/lib/bundler/setup.rb`
- `rubygems/bundler/lib/bundler/runtime.rb`
- `rubygems/bundler/lib/bundler/rubygems_integration.rb`
- `rubygems/bundler/lib/bundler/shared_helpers.rb`
- `rubygems/bundler/lib/bundler/definition.rb`

### `require "bundler"` vs `require "bundler/setup"`

`require "bundler"` loads Bundler's library and module state.

`require "bundler/setup"` runs `Bundler.setup`, which in `bundler.rb` does:

1. `configure_custom_gemfile`
2. build/validate the `Definition`
3. call `load.setup`

That `load.setup` is `Bundler::Runtime#setup`.

### `Bundler::Runtime#setup`

In `bundler/runtime.rb`, the important flow is:

1. `clean_load_path`
2. `specs = @definition.specs_for(groups)`
3. `SharedHelpers.set_bundle_environment`
4. `Bundler.rubygems.replace_entrypoints(specs)`
5. for each spec: `mark_loaded(spec)`
6. collect spec load paths
7. `Gem.add_to_load_path(*load_paths)`

This is the core answer to "what does Bundler actually do at runtime?"

It does **not** only compute a dependency graph. It mutates runtime state:

- process `ENV`
- RubyGems entrypoints
- `Gem.loaded_specs`
- `Gem::Specification.all`
- `$LOAD_PATH`

### `Bundler::RubygemsIntegration#replace_entrypoints`

This method in `bundler/rubygems_integration.rb` is the most important bridge.

It:

1. disables or reverses normal RubyGems auto-activation,
2. replaces `Kernel#gem`,
3. stubs RubyGems' view of available specs,
4. replaces executable lookup,
5. clears RubyGems path caches.

The most important sub-steps are:

- `reverse_rubygems_kernel_mixin`
- `replace_gem`
- `stub_rubygems`
- `Gem.clear_paths`

And `stub_rubygems` does:

```ruby
Gem::Specification.all = specs
Gem.post_reset { Gem::Specification.all = specs }
```

That line is the reason a simple `Gem.loaded_specs` split is not enough.

Bundler is not only tracking "loaded" gems. It is replacing RubyGems' whole spec catalog with a bundle-specific list.

## 6. The three states that are easy to confuse

These are related, but different:

| State | Backing structure | Typical writer |
| --- | --- | --- |
| Feature was required | `$LOADED_FEATURES` | Ruby core `require_internal` |
| Gem is activated | `Gem.loaded_specs` | RubyGems `spec.activate`, Bundler `mark_loaded` |
| Gem is considered available by the current runtime | `Gem::Specification` registries | RubyGems reset/loading, Bundler `stub_rubygems` |

If you are debugging weird gem behavior, always ask which of these is wrong.

Typical failure modes:

- file missing from `$LOAD_PATH` -> plain `LoadError`
- wrong spec in `Gem.loaded_specs` -> "already activated" conflict
- wrong `Gem::Specification.all` / spec registry -> Bundler and RubyGems disagree about what exists

## 7. What is already box-local, and what is not

### Box-local today

These are the encouraging parts:

1. `$LOAD_PATH` is box-local.
2. `$LOADED_FEATURES` is box-local.
3. `require` works against the loading box.
4. `Bundler` itself can be box-local if first required inside the box.

Runtime probe:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler'; Bundler.instance_variable_set(:@setup, :box1)")
box2.eval("require 'bundler'; Bundler.instance_variable_set(:@setup, :box2)")
```

Observed result:

- `Bundler` remained undefined in main,
- each box got a different `Bundler.object_id`,
- each box had its own `@setup` value.

So the statement "Bundler must be one global module for the whole process" is **not** the real blocker.

### Remaining boundaries

#### `ENV` is process-global

Another direct probe result:

```ruby
box.eval("ENV['BOX_TEST_FOO'] = 'x'")
```

changes `ENV["BOX_TEST_FOO"]` in main too.

That matters because Bundler still uses process-global environment discovery:

- `BUNDLE_GEMFILE`
- `BUNDLE_LOCKFILE`
- `RUBYOPT`
- `RUBYLIB`
- `PATH`

This is separate from the activation-isolation problem, but still relevant.

It is also why `Carton.with_bundle` scopes `BUNDLE_GEMFILE` and clears any
stale `BUNDLE_LOCKFILE`: Bundler reads both from process-global `ENV`, and a
leftover lockfile path would override the lockfile Bundler would otherwise
derive from the selected Gemfile.

#### Path-gem method dispatch

Path-gem setup crosses RubyGems and Bundler classes loaded through different
box contexts. The current integration prototype exposes two Ruby lookup bugs:

- `flat_map(&:expanded_dependencies)` cannot see a method that direct dispatch
  can see,
- `Bundler::Dependency#initialize` resolves `super` to
  `BasicObject#initialize` instead of boxed `Gem::Dependency#initialize`.

These are Ruby dispatch problems. Rewriting the symbol proc as an explicit
block is only diagnostic.

#### `bundle exec` prelude

With boxes enabled, `bundle exec` can evaluate the application gemspec before
`Gem::Specification` is visible. This fails before Carton or application code
can install a workaround.

## 8. Public APIs that matter for advanced gem/runtime work

### Ruby core

| API | Use it for | Notes |
| --- | --- | --- |
| `require` | loading features | always the starting point |
| `load` | force reload of a file | lower-level than `require` |
| `$LOAD_PATH` | inspecting or adjusting search paths | box-local under `Ruby::Box` |
| `$LOADED_FEATURES` | seeing which files actually loaded | file-level, not gem-level |
| `$LOAD_PATH.resolve_feature_path(feature)` | asking Ruby how it would resolve a feature | useful for embedders like Carton |

### RubyGems

| API | Use it for | Notes |
| --- | --- | --- |
| `gem(name, *requirements)` | explicit activation before requiring | avoid under Bundler unless you mean it |
| `Gem.loaded_specs` | inspect activated gems | read-mostly for applications |
| `Gem::Specification.find_by_name` | query specs by name/version | uses RubyGems spec registry |
| `Gem::Specification.reset` | rebuild spec view after path changes | heavy; Bundler hooks into this |
| `Gem.clear_paths` | clear path-related RubyGems caches | Bundler calls this after replacing entrypoints |
| `Gem.use_paths` | replace gem home/path roots | broad process-level change |

### Bundler

| API | Use it for | Notes |
| --- | --- | --- |
| `require "bundler/setup"` | activate the bundle | preferred entrypoint |
| `Bundler.setup(*groups)` | same thing with explicit groups | should happen early |
| `Bundler.require(*groups)` | require gem entry files | convenience only |
| `Bundler.reset!` | clear Bundler memoized state | not enough for multi-bundle isolation by itself |
| `Bundler.with_unbundled_env` | spawn subprocesses outside current bundle | useful escape hatch |

### APIs applications usually should not lean on unless they are building runtime tooling

- `Bundler::SharedHelpers`
- `Bundler.rubygems.replace_entrypoints`
- `Gem::Specification.all=`
- `Gem::Specification.specification_record`

These are the exact areas Carton and any upstream isolation work eventually need to care about, but they are not "ordinary app code" APIs.

## 9. Implications for Carton

Carton's current design matches the runtime facts:

- `Carton::Runtime.import` resolves names in the caller box and only carries the matching load-path entry into the imported box.
- `Carton.with_bundle` scopes `ENV["BUNDLE_GEMFILE"]`, clears stale `ENV["BUNDLE_LOCKFILE"]`, and redefines the path-gem load-path lookup in the current Box because Bundler still discovers bundle files from process-global environment state.
- `Carton.bootstrap_rubygems!` is retained as compatibility code while the
  boxed Bundler path is experimental.
- `Carton::Runtime.import` still snapshots/restores `Gem.loaded_specs` around a
  bootstrapped import, though Ruby 4.0.5 probes showed registry state was
  already Box-local.

Ruby 4.0.5 runtime probes showed:

- two boxes activate conflicting non-path bundle versions,
- Main Box remains unactivated,
- an already-bundled Main Box can activate a conflicting version in an optional Box,
- ordinary process exit succeeds.

On Ruby 4.0.5, two gaps remained: Bundler path gems failed inside a stock Box
while assigning Bundler's `source` metadata, and `RUBY_BOX=1 bundle exec`
failed in prelude with `Gem::Specification` unavailable before application
code ran. Both require reproduction on Ruby 4.0.6.

The Ruby 4.0.5 ceiling was explained cleanly:

1. Ruby core isolates load state and RubyGems registry state.
2. Bundler can load independently per box.
3. `ENV` remains process-global and must be scoped explicitly.
4. earlier path-gem failures implicated method lookup across Box class extensions,
5. the 4.0.6 prelude model must be tested before retaining the earlier `bundle exec` diagnosis.

So the long-term shape for Carton is:

- keep using box-local `require "bundler/setup"` as the entry model,
- keep compatibility code explicit and removable,
- reproduce the earlier Ruby method-dispatch and prelude blockers on 4.0.6,
- fix only the blockers that remain,
- remove Carton's RubyGems registry patch once end-to-end path-bundle coverage
  passes without it.

That last point matters. The source reading and probes strongly suggest the first viable solution is **not** "give each box a brand new VM-level Bundler." The first viable solution is:

> let each Box keep its own Bundler module and RubyGems state, then fix only
> method-dispatch paths that still fail under Ruby 4.0.6.

That is exactly the boundary Carton's upstream plan should target.
