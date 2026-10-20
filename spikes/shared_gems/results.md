# Shared Gems Boxes results

Measured on 2026-10-20 from `origin/main` commit `ea6b649`, on branch `spike/shared-gems`. Ruby `4.0.7`, revision `229531a6cf`, Prism, `arm64-darwin27`; RubyGems and Bundler `4.0.23`; Apple M5 Pro Virtual, 16 GiB RAM. Active Support `8.1.4`, concurrent-ruby `1.3.8`, Zeitwerk `2.8.3`. The standalone [lockfile](Gemfile.lock) pins the dependency set. Rails experiments use the unchanged [Rails example lockfile](../../examples/rails_in_cartons/Gemfile.lock).

## Recommendation

Userspace sharing works for a useful, explicit subset. It is not ready to replace Carton's dependency loading. Keep this prototype separate from production. The one-time Active Support load and sub-millisecond installation are worth investigating further, but the require contract and builtin-state compatibility need decisions and tests before a runtime feature.

The minimum method-transplantation requirement succeeds. Selected full Active Support checks succeed in two fresh Boxes without requiring Active Support there. Two plain Cartons preserve their application boundaries, and two Active Record domain Cartons use shared Rails dependencies and SQLite. Ordinary Gem Carton activation, a local shared-feature require, and the unmodified Rails example fail. This is outcome 2 from the handoff, with outcome 3 still possible if compatibility work becomes too large. It is not strong success or arbitrary-gem compatibility.

## First milestone

The [original probe](01_method_transplant.rb) fails before transplantation:

```text
undefined method 'box' for an instance of UnboundMethod (NoMethodError)
```

Ruby 4.0.7 has `Method#box`, but no `UnboundMethod#box`. The original expectation remains in that file. The [separate transplant probe](02_builtin_isolation.rb) verifies provenance with a bound `Method#box`, `Ruby::Box.current` inside the shared body, and UnboundMethod equality. The target's method body reads Gems constants, calls Gems patches, and executes in Gems. Billing can replace it locally while Shipping and Gems retain the original. Main and Master do not gain that method. No wrapper recompiles the dependency body.

## Compatibility matrix

Verified means the assertions passed for the specific experiment, not for all libraries using that mechanism. Failed means the intended general behavior did not hold. Untested behavior is not implied by a neighboring success.

| Behavior | Status | Evidence and boundary |
| --- | --- | --- |
| Builtin Ruby method transplantation | Verified | `02`: String method works directly from target-defined code. |
| Defining Box, constants, ownership and method identity | Verified | Bound Method reports Gems; UnboundMethod equals source; owner remains String. |
| Independent target overrides | Verified | Billing changes its implementation; Shipping, Gems, Main and Master retain their prior state. |
| Positional/keyword arguments, blocks, captured closures | Verified | `02`, including a define_method closure. |
| Aliases, new public/protected/private definitions | Verified | `02` and `00`. Installer explicitly reapplies visibility. |
| Visibility-only mutation of an existing builtin | Failed | `09`: protecting String#upcase in Gems also changes Main, Shipping and Master. |
| Singleton methods on the same builtin singleton class | Verified | String's singleton class has compatible identity across Boxes. |
| Singleton methods on unrelated class owners | Failed by design | `02` asserts TypeError; Ruby's owner compatibility check rejects rebinding. |
| Exceptions and backtraces | Verified | Shared ArgumentError and a shared_failure frame survive transplantation. |
| Concurrent calls | Verified | Eight threads perform 100 shared calls each; no concurrent mutation test. |
| Shared top-level/nested classes, class methods, inheritance | Verified | `03`; child application subclasses retain their own execution Box. |
| Mutable dependency registries and reopening | Verified shared | `03`: dependency array and reopened class change for all holders. This is intentional sharing. |
| Include/prepend order and super | Verified subset | `04`: two overlapping prepend modules and an included method match source ancestry. |
| Copying an effective prepended method onto its class | Failed | Changes `second, first, include` to `second, first, second, include`. Copy only directly owned methods. |
| Repeated ancestor installation | Verified subset | No duplicate ancestors; prototype skips already present modules. |
| Include/prepend callback context | Verified with limitation | Callbacks execute in Gems. A callback defining a method on a builtin changes Gems, not the consumer. |
| Add/replace/remove/undef/alias/visibility discovery | Verified synthetic | `00`; replacements use method equality. Removal versus undef is distinguishable with an inherited fallback; ambiguous direct-method disappearance is reported and refused. |
| Builtin constants, ivars, cvars and autoload changes | Unsupported | Manifest reports shallow differences and does not install those changes. |
| In-place mutation inside captured state objects | Untested/incomplete | Snapshot values retain references; equality cannot reliably discover arbitrary internal mutation. |
| Targeted Active Support blank/time extensions | Verified | `05 --targeted`: six checks in each of two consumers. |
| Full core_ext with the initial builtin list | Failed | Enumerable#compact_blank missing from consumer. |
| Full core_ext with expanded builtin list | Verified selected checks | `05 --extended`: all 15 comparisons match in each of two consumers. |
| Child-defined application methods using patches | Verified | Invoice#valid_name? executes name.present? in the child's Box. |
| ActiveSupport::Duration, Time, Date, inflection, Hash, Array | Verified selected checks | `05`, compared with ordinary loading at the same locked versions. |
| Expected Active Support exceptions | Verified | Array#to_sentence rejects unknown options with matching exception class and message. |
| BigDecimal/native JSON calls through shared definitions | Verified selected calls | `05` and `11`; not a general native-extension safety claim. |
| Shared module autoload | Verified synthetic | `06`: autoload creates its class in Gems. |
| Lazy require from shared method, including during child.require | Verified synthetic | Both execution and feature registration stay in Gems for these call paths. |
| Lazy Active Support dependency use | Verified selected call | Transliteration returns cafe; benchmark records its first-call cost. |
| Local require of an already-shared feature | Failed | concurrent-ruby classes reopen; NameError for Concurrent::Map#freeze, with partial initialization and duplicate constant warnings. |
| Child feature records | Verified honest | Active Support files are absent from child $LOADED_FEATURES; no fabricated entries. |
| Child gem activation and bundle restrictions | Absent | `11`: Gems has the locked versions and rejects rake; child has no Active Support activation and can activate rake. |
| Nonshared dependency loading | Verified subset | Child loads set/rake normally before any failed shared-feature reload. |
| Independent conflicting versions outside sharing | Verified | A fresh unmodified Box loads Active Support 8.1.2 beside the 8.1.4 Gems bundle. |
| Conflicting versions inside a shared consumer | Unsupported | No resolver or safety guard is implemented; sharing must not be selected for such a Carton. |
| Shared Zeitwerk loader for application code | Failed by default | `11`: loader creates SharedWidget in Gems, absent from the child. Explicit child namespaces remain untested here. |
| Two plain Cartons, nested imports and cache identity | Verified | `07`, using a process-local private lifecycle hook. |
| Public Surface and private application constants | Verified | Bare Carton exposes only LOCAL; explicit exports and application class identities stay separate. |
| Existing Gem Carton activation | Failed | `07 --gem`: Psych reload reopens shared objects and raises SyntaxError in generated ClassLoader code. |
| Two compatible Gem Cartons | Untested | Activation fails before the first fixture Gem Carton completes. |
| Two Active Record domain Cartons | Verified | `10`: separate Invoice classes use present?, insert rows and query the same in-memory SQLite database. |
| Unmodified Rails-in-Cartons example with sharing hook | Failed | `10 --existing`: same Psych activation failure. |
| Full Rails requests, reloading and arbitrary framework callbacks | Untested | The Rails-domain test is not a full Rails application boot or request benchmark. |
| Strict Gem Cartons, multiple shared bundles, concurrent installation | Untested | Outside this spike's supported contract. |

The [inspectable Active Support manifest](active_support_manifest.json) records 371 directly installed method definitions per consumer, plus ancestor additions and shared top-level constants. Discovery initially covers the handoff's 16 classes/modules, tolerates an absent Date, then adds Enumerable, Range, Float and Regexp for the expanded run. Date and other newly loaded non-builtin classes are shared objects, not copied class-extension tables.

## Loading and activation failures

The helper deliberately leaves child `$LOADED_FEATURES` and `Gem.loaded_specs` unchanged. This makes the state truthful, but means Ruby's ordinary loader sees shared files as not loaded. Requiring `active_support/core_ext/object/blank` in a consumer starts executing dependency sources again against shared Concurrent classes and fails while initializing Concurrent::Map. This is worse than redundant work: the attempt has already mutated shared objects. Tests run it in a disposable process.

The integration hook installs after Carton boots in a new Box, before its existing activation and Entrypoint loading. Plain Cartons work. Gem Carton's normal YAML spec reconstruction then loads Psych into a Box already bound to shared Psych objects. Reopening Psych::ClassLoader encounters existing cache constants in its method-generation loop and raises SyntaxError. The existing Rails example follows the same path. This is a failure of this hook and contract, not evidence that every possible integration seam must fail.

Installing after activation might avoid reopening some infrastructure, but would encounter existing child constants with different identities. The current installer rejects constant collisions. It does not preflight every change or roll back partial installation. Neither moving the hook nor copying loaded features is a verified solution.

A shared method's execution Box is still useful for lazy dependency loading: the synthetic direct and nested-require calls both load in Gems, and shared-module autoload does too. That result does not prove every native callback or loading-stack combination behaves identically. A shared Zeitwerk loader illustrates the other side of retained context: its default application namespace is Gems. Dependency implementation sharing and application autoload ownership need separate contracts.

## Performance

The raw [Active Support results](benchmark_active_support.json) and [synthetic results](benchmark_synthetic.json) contain all 20 rows each, with initialization, creation, installation, boot, RSS, source compilation, feature loads, installed-definition counts and first lazy-call timing. Each row uses a fresh Ruby process. Measurements are single samples, not medians or a performance guarantee. Some correctness probes ran alongside the exploratory Active Support pass, so use the scale of the difference rather than small timing deltas.

Boot times below begin after Ruby loads the benchmark's support code and end after dependency initialization and application checks. They include observer loads and scratch-file creation where applicable, but exclude interpreter startup, the final explicit GC/RSS sample, and the separately timed lazy call. Installation timing includes the pre-install feature observation. The existing-Carton control imports plain Cartons that each call setup_bundle and require the dependencies. It measures the existing runtime with the same dependency workload, not strict Gem Carton activation.

The Master control alone writes Master, in its disposable worker. It is an unsupported behavioral and performance control. No prototype installer directly writes to Master. Ruby's visibility bug remains a separate exception to that isolation claim.

Active Support boot seconds:

| Boxes | Independent | Shared | Master control | Existing Carton |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.761 | 0.801 | 0.157 | 0.759 |
| 5 | 3.585 | 1.066 | 0.280 | 3.607 |
| 10 | 7.370 | 1.316 | 0.444 | 7.452 |
| 25 | 18.687 | 2.235 | 0.945 | 20.135 |
| 50 | 38.856 | 3.778 | 1.733 | 39.632 |

Retained process RSS in MiB after GC, including baseline Ruby and the shared dependency Box:

| Boxes | Independent | Shared | Master control | Existing Carton |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 52.703 | 55.156 | 52.812 | 51.797 |
| 5 | 127.969 | 65.891 | 64.984 | 133.125 |
| 10 | 221.125 | 78.266 | 77.078 | 228.625 |
| 25 | 515.938 | 109.453 | 114.453 | 526.734 |
| 50 | 1056.812 | 165.016 | 184.281 | 1046.500 |

Shared initialization takes 722 to 758 ms across these rows, including Bundler setup, Box creation and reflection. Installation averages 0.55 to 0.82 ms per consumer, excluding Box creation. Creating each consumer still costs about 58 to 62 ms. At 50 consumers, installation writes 18,550 method definitions; dependency compilation remains 222 Ruby files, compared with 11,051 across independent consumers. Gem feature-load records total 351 with sharing and 17,501 independently. The compilation count is a proxy for successful source-file evaluation, excludes installer eval strings, and includes repeated loads of the same path. Gem feature-load counts include transitive dependencies rather than only public entrypoint requires. Ruby compilation is observed through TracePoint; feature counts use loaded-feature deltas and include native registrations.

The shared run's extra retained memory grows about 2.24 MiB per additional consumer between 1 and 50 Boxes, versus about 20.49 MiB independently. Raw JSON also includes each process's baseline RSS, total RSS increase and the amortized increase per Box; those amortized values include one-time initialization and must not be mistaken for the marginal cost. RSS is not peak memory or a Ruby object-heap measurement. It comes from macOS ps, so this benchmark's RSS reader needs a different implementation on systems without that interface.

The first transliteration after boot takes approximately 3.9 to 9.7 ms in shared runs. That is a single lazy dependency exercise, not a bound on all later lazy loading.

The synthetic dependency adds one String method and one module. It demonstrates that sharing does not improve trivial dependency loads; the extra Gems Box and discovery can cost more:

| Boxes | Independent | Shared | Master control | Existing Carton |
| ---: | ---: | ---: | ---: | ---: |
| 1 | 0.065 | 0.123 | 0.062 | 0.059 |
| 5 | 0.311 | 0.360 | 0.367 | 0.302 |
| 10 | 0.597 | 0.709 | 0.597 | 0.614 |
| 25 | 1.559 | 1.581 | 1.524 | 1.549 |
| 50 | 3.042 | 3.094 | 3.039 | 3.107 |

The separate Rails-domain experiment initialized Rails dependencies in 0.995 s and finished two persisted domain models in 1.276 s in one uninstrumented sample. It uses Rails/Active Record and native SQLite, but does not initialize and serve a full Rails application. There is no compatible shared version of the existing request-level example to benchmark yet. Full Rails application time/memory comparisons and 1 to 50 domain Rails scaling remain untested; the Active Support numbers cannot stand in for them.

## Ruby source and the missing VM support

The source investigation used the exact `v4.0.7` tag, commit `229531a6cfbf07e3caef30dbac24a2a3f3fed482`, matching the installed Ruby revision.

- [proc.c method registrations](https://github.com/ruby/ruby/blob/v4.0.7/proc.c#L4630-L4657) define Method#box and omit UnboundMethod#box.
- [proc.c define_method](https://github.com/ruby/ruby/blob/v4.0.7/proc.c#L2426-L2474) accepts Method/UnboundMethod, checks owner compatibility and installs its method entry. [vm_method.c](https://github.com/ruby/ruby/blob/v4.0.7/vm_method.c#L1682-L1704) retains the supplied underlying definition. [vm.c](https://github.com/ruby/ruby/blob/v4.0.7/vm.c#L3150-L3167) derives the current Box from that definition. These paths explain the observed method provenance.
- [proc.c super_method](https://github.com/ruby/ruby/blob/v4.0.7/proc.c#L3591-L3615) walks the method's defined class and original method ID. The duplicate prepend-chain probe demonstrates why effective lookup results cannot simply be copied onto their receiver class.
- [class.c method-table copying](https://github.com/ruby/ruby/blob/v4.0.7/class.c#L211-L236) shares method-entry pointers across copied tables. [vm_method.c rb_export_method](https://github.com/ruby/ruby/blob/v4.0.7/vm_method.c#L2227-L2264) directly changes a matching entry's visibility flag. That explains the visibility leak. A narrow fix would clone the method entry into the current Box's writable method table before changing visibility, retaining the shared definition. This diagnosis is source-backed, but the fix is not implemented or validated here.

No VM change is needed for basic method transplantation. The smallest additional native capability relevant to general sharing would copy a selected builtin class/module's Box-specific extension state into a target Box, preserving method definitions, constants, variables, singleton state and ancestor ordering without rerunning Ruby callbacks. A native template Box mechanism could provide that more broadly. The experiment does not settle an API, and such copying would still leave application-owned loading, gem activation and shared-feature require semantics to be designed. A resolved gem load path alone does not share evaluated definitions.

## Minimal integration direction

A. Recommended now: retain this as research, keep ordinary loading as the production behavior, and report the independent visibility bug upstream. No issue or PR was posted by this task.

B. A useful next spike could opt plain Cartons into an explicit, versioned dependency manifest before their Entrypoint and Public Surface snapshot. It would share only dependencies with tested manifests, keep their Box alive, bind approved constants, and replay directly owned methods/ancestors. It must reject incompatible preexisting constants and dependency versions before installation. Application code would omit local requires of shared features, as the successful tests do. Whether later requires should refuse, delegate or opt out remains undecided; ordinary local require is now a tested failure.

C. If supporting existing Gem Carton activation, arbitrary callbacks and builtin state requires extensive compatibility machinery, use these results to narrow the native template proposal instead. Keep conflicting dependencies independently loaded. Do not trade away Carton's existing per-Carton version selection to make sharing appear successful.

No production files under lib/, public APIs, import/export semantics, existing examples, gem versions, or packaging were changed. The lifecycle hooks exist only inside experiment processes. No new domain contract has been accepted.

## Validation

`RUBY_BOX=1 ruby spikes/shared_gems/run.rb` checks 15 cases in separate processes, including four intentional nonzero failures. Internal observed-failure probes also assert the specific require and visibility defects. `bundle exec rubocop spikes/shared_gems` checks the experiment code, which the repository's normal RuboCop file list does not include. `bundle exec rake format` formats it with the rest of the repository.

The final repository check, `bundle exec rake`, passed 225 tests with 724 assertions, its 147-file RuboCop check, and every registered example, including the Rails request/reloading regression test. This confirms the ordinary runtime still passes without the experiment's process-local hooks.
