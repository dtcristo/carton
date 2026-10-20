# How Ruby gems, RubyGems, Bundler, and `Ruby::Box` fit together

This guide is based on direct reading of the upstream Ruby, RubyGems, and Bundler source trees.

It describes Ruby 4.0.7 with RubyGems/Bundler 4.0.23. Older-version failures and their fixes are listed in [upstream.md](upstream.md#resolved).

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

`Ruby::Box` makes key Ruby runtime structures Box-local, especially:

- `$LOAD_PATH`
- `$LOADED_FEATURES`
- global variables that Ruby marks Box-ready
- class/module constant tables and method tables through class-extension copy-on-write

That means file loading itself is already much more isolated than normal Ruby.

RubyGems and Bundler are mostly Ruby code running on top of that runtime, so their behavior also depends on Ruby method lookup across Boxes.

The most important Ruby 4.0.7 facts are:

1. **Master Box is the copy source for Root, Main, and Optional Boxes.**
2. **Root runs bootstrap/builtins; Main runs the application.**
3. **Prelude helpers such as RubyGems are loaded into User Boxes independently.**
4. Therefore `require "rubygems"` is already satisfied in a fresh Optional Box without inheriting Main or Root state.
5. **Bundler is not preloaded that way.** If the first `require "bundler"` happens inside a Box, that Box gets its own `Bundler` constant and module state.
6. RubyGems definitions and activation state belong to each User Box.
7. Per-Carton Bundler setup, path-gem imports, and boxed `bundle exec` work on 4.0.7 with Bundler 4.0.23.

That is why running Bundler setup inside each Carton remains the right isolation shape.

### Ruby 4.0.7 confirmed behavior

On Ruby 4.0.7 with Bundler 4.0.23:

- `$LOAD_PATH`, `Gem.loaded_specs`, and RubyGems registry changes stay Box-local.
- `Bundler` module state is Box-local if Bundler is first loaded inside the Box.
- conflicting non-path bundles work in separate Boxes, including under an already-bundled Main Box.
- app-bundle path gems import as Cartons; Imported Carton Gemfiles keep their intended versions without mutating Main Box.
- fresh Optional Boxes start with no gem load paths or gem loaded features, even when Main ran under `bundle exec`.
- `RUBY_BOX=1 bundle exec` evaluates gemspecs and starts the app.
- a fresh Box auto-activates the newest installed version of a gem on `require`, ignoring the importer's lockfile. Carton activates an imported gem's Gem Closure first to prevent this, default gems included, since a newer installed version would otherwise replace the importer's. Default gems are activated first, from the Box's own default specs: the YAML rebuild below loads Psych, whose requires (such as `date`) would otherwise activate the newest installed version before the caller's.
- spec objects from another Box run that Box's methods, so calling `activate` on them updates the wrong Box. Carton rebuilds each spec with `Gem::Specification.from_yaml(spec.to_spec.to_yaml)` and restores `loaded_from` and `full_gem_path`, which also avoids re-evaluating gemspecs.
- a bundled importer's restriction carries into a Carton Box through `Bundler.rubygems.replace_entrypoints(specs)` on the rebuilt specs: locked gems load at their versions, default gems still load, and unlocked gems raise `LoadError`. Under that restriction RubyGems does not auto-activate, so every locked spec must be activated, as `Bundler.setup` does.
- the `bundler` spec is never shared: the Box loads its own Bundler to apply the restriction, which can be a different version from the Importer's, and activating both raises `Gem::LoadError`.
- activation costs well under a millisecond per gem; `Ruby::Box.new` itself is about 70ms.

That is why Carton's per-Carton Bundler pattern is one line, the same as the top-level app's:

```ruby
# cartons/my_carton/lib/my_carton.rb
Carton.setup_bundle
```

Carton patches nothing in RubyGems or Bundler. Restricting a Gem Carton to the importer's lockfile calls two Bundler internals; see [upstream.md](upstream.md#resolve-once-activate-in-many-boxes).

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

Ruby wires `$LOAD_PATH` and `$LOADED_FEATURES` through Box-aware getters:

- `load_path_getter` returns `rb_loading_box()->load_path`
- `get_LOADED_FEATURES` returns `rb_loading_box()->loaded_features`
- `rb_gvar_box_ready("$LOAD_PATH")`
- `rb_gvar_box_ready("$LOADED_FEATURES")`

That is the first crucial point: **load state is attached to the loading Box, not just to the current lexical context.**

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

and then uses that Box for feature lookup and feature registration.

So from Ruby core's point of view, the important state is already Box-local:

- load path
- loaded features
- feature index
- loading table
- extension handle map

## 2. `Ruby::Box`: what a Box actually contains

The key structure is `rb_box_t` in `ruby/internal/box.h`.

Each Box carries its own:

- `load_path`
- `expanded_load_path`
- `loaded_features`
- `loaded_features_index`
- `loading_table`
- `ruby_dln_libmap`
- `gvar_tbl`
- `classext_cow_classes`

Since Ruby 4.0.6, `box_entry_initialize` creates each Box by duplicating state from the **Master Box**:

- `box->load_path = rb_ary_dup(master->load_path)`
- `box->loaded_features = rb_ary_dup(master->loaded_features)`
- `box->loaded_features_realpaths = rb_hash_dup(master->loaded_features_realpaths)`

That means a new Box does **not** start from the caller, Main, or Root. It starts from Master.

This is why Carton resolves feature names in the importer's Box and only carries the matching load-path entry into the Carton Box when that feature root is needed.

## 3. Ruby boot order: why RubyGems is local to each User Box

The key files are:

- `ruby/ruby.c`
- `ruby/gem_prelude.rb`

Since Ruby 4.0.6, Root and Main are initialized from Master before prelude loading. The gem prelude does:

```ruby
require "rubygems"
require "bundled_gems"
```

if `Gem` is defined. `rubygems.rb` ends by requiring `ENV["BUNDLER_SETUP"]` when it is set, which is how `bundle exec` sets up the bundle early. Since Ruby 4.0.7 the prelude skips that outside Main Box ([Bug #22123](https://bugs.ruby-lang.org/issues/22123)), so a new Optional Box no longer runs the caller's `bundler/setup` while loading RubyGems.

Ruby loads these prelude helpers into Main and optional User Boxes independently. Thus `require "rubygems"` is already satisfied in each User Box, but not because its `$LOADED_FEATURES` was copied from Root. RubyGems definitions and activation state belong to that Box's environment.

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

## 7. What is already Box-local, and what is not

### Box-local today

These are the encouraging parts:

1. `$LOAD_PATH` is Box-local.
2. `$LOADED_FEATURES` is Box-local.
3. `require` works against the loading Box.
4. `Bundler` itself can be Box-local if first required inside the Box.

Runtime probe:

```ruby
box1 = Ruby::Box.new
box2 = Ruby::Box.new

box1.eval("require 'bundler'; Bundler.instance_variable_set(:@setup, :box1)")
box2.eval("require 'bundler'; Bundler.instance_variable_set(:@setup, :box2)")
```

Observed result:

- `Bundler` remained undefined in main,
- each Box got a different `Bundler.object_id`,
- each Box had its own `@setup` value.

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

Bundler reads `BUNDLE_GEMFILE` and `BUNDLE_LOCKFILE` to find the bundle, so `Carton.setup_bundle` sets the first and clears any stale second. A leftover lockfile path would override the lockfile Bundler derives from the selected Gemfile.

Bundler also writes `ENV` during setup. `SharedHelpers.set_bundle_environment` exports `RUBYOPT=-rbundler/setup`, `RUBYLIB`, `BUNDLER_SETUP`, `GEM_HOME`, `PATH`, and `BUNDLER_ORIG_*` so subprocesses inherit the bundle. Those writes reach every Box, so `setup_bundle` snapshots `ENV` first and restores all of it after setup.

## 8. Public APIs that matter for advanced gem/runtime work

### Ruby core

| API | Use it for | Notes |
| --- | --- | --- |
| `require` | loading features | always the starting point |
| `load` | force reload of a file | lower-level than `require` |
| `$LOAD_PATH` | inspecting or adjusting search paths | Box-local under `Ruby::Box` |
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

- `Carton::Runtime.import` resolves names in the importer's Box and only carries the matching load-path entry into the Carton Box.
- Each Carton runs `Bundler.setup` in its own Box, so activation stays there; Carton adds no RubyGems or Bundler patches.
- `Carton.setup_bundle` manages the process-global `ENV` that Bundler reads.
- A Gem Carton gets the importer's activated versions: Carton rebuilds the specs in the new Box and activates them there, restricted to the importer's lockfile when the caller is bundled.

> Let each Box keep its own Bundler module and RubyGems state, manage the process-global `ENV` that Bundler reads and writes, and carry the importer's gem versions into Gem Cartons.

## Shared Gems spike

The [standalone prototype](../../spikes/shared_gems/results.md) shares gem-defined objects and transplants builtin patches without copying `$LOADED_FEATURES` or child activation state. Its selected Active Support behaviors work without child source loads, including methods defined in application Cartons. A later local require reopens shared dependency classes and fails in concurrent-ruby; the experimental Carton hook also fails during existing Gem Carton activation's Psych load. Installing definitions therefore does not replace the activation and loading model described above. Shared Zeitwerk loaders need separate treatment because their default application namespace belongs to the Gems Box.
