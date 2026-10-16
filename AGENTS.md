# Agents

Guidance and memory for agents working on this repo.

## Memory bank

- Goal: make Carton feel like part of Ruby: built-in, simple, streamlined, and not verbose.
- Prefer simpler implementation over complexity.
- Keep the public API small and Ruby-like.
- Keep the library feeling native to Ruby; explicit setup is fine when it keeps behavior simple and unsurprising.
- The project should work with or without Bundler.
- A package in this system is called a carton, though docs can still use "package" in plain English when it reads better.
- Keep optional Bundler/RubyGems support clearly separated from the core import/export runtime.
- Target Ruby 4.0.7 or later (Bundler 4.0.23+): Master Box is the immutable copy source, Root Box runs bootstrap/builtins, Main Box runs the application, and Cartons run in optional Boxes.
- Optional Boxes do not inherit Root or Main state; resolve imports in the caller and carry only the required load-path entry forward.
- A Bare Carton's Public Surface includes only constants and top-level helpers introduced by its Entrypoint; it is returned as `Carton::Exports`, never the Box (user decision: importers must not reach another Carton's Box).
- Full pattern deconstruction enumerates every Named Export or the Bare Carton's discovered Public Surface.
- Ruby 4.0.7 gives each Box its own RubyGems state and clean gem paths; Carton patches nothing in RubyGems or Bundler and only scopes `BUNDLE_GEMFILE`/`BUNDLE_LOCKFILE`. Re-add a gem workaround only with a failing test on the current release.
- `RUBY_BOX=1 bundle exec` works on Ruby 4.0.7 with Bundler 4.0.23. Ruby 4.0.7's prelude skips `BUNDLER_SETUP` outside Main Box (Bug #22123), which is what removed Carton's Box-creation workarounds.
- Bundler setup writes subprocess `ENV` (`RUBYOPT`, `BUNDLER_SETUP`, ...); `setup_bundle` restores all of `ENV` afterwards, so Cartons never leak bundle variables into the process.
- Gem Cartons share the caller's activated gems: an Import owned by an activated gem activates that gem's dependency closure in the new Box, rebuilt from YAML because foreign-Box spec objects run their own Box's methods. The cache records those versions and raises when a later importer's differ. A bundled caller's lockfile also restricts the Box via Bundler internals confined to `GemActivation`.
- Code run by `box.eval` sees the loading Box's `$LOAD_PATH` (the importing Carton during a nested Import); mutate a Box's load state from a file `require`d in it.
- `Carton.setup_bundle(*groups, gemfile:)` mirrors `Bundler.setup` and restores `ENV` afterwards; check `Bundler.root` (memoized), not `Bundler.default_gemfile` (rereads `ENV`), when testing which Gemfile was selected.
- Imports are shared process-wide, keyed by Entrypoint real path; the Main Box's `ImportCache` and loader build every Carton (user decision; replaces the earlier avoid-a-global-cache note).
- Only the imported Entrypoint declares exports; `export` elsewhere (plain `require`, files a Carton requires) validates and is inert, so Carton-aware gems still work via `require`.
- `export` may be called many times per Entrypoint (user decision). Capitalized Symbols name top-level constants, other Symbols top-level methods, keywords plain values; names resolve at the call, like `private`. Lookups return `Method` objects and never invoke values or bare helpers.
- `export_default value` is exclusive: once per file, never with `export` (user decision; ESM-style `default:` slots and import name selection were tried and dropped). Bind a default to its own name; rename only for clashes.
- Gems export their root module with `export_default` and hide internals with Ruby's `private_constant`, which holds across Boxes; Carton adds no visibility mechanism of its own.
- Two Rails shapes work: Rails in the Main Box with plain-Ruby domain Cartons (`examples/rails_in_main`), or Rails loaded once in a framework Carton that domain Cartons subclass from (`examples/rails_in_cartons`). Cross-Box subclassing works because inherited methods run in the defining Box; Rails name lookups need the domain classes registered (`Object.const_set`) in the framework Box, and Active Support core extensions stay Box-local. Zeitwerk works inside a Carton Box.
- Box-local monkey patches apply only to classes created while Master is current (builtins). Classes created in a user Box have one shared, writable definition: reopening a class another Carton defined changes it in every Box. Documented mitigations only (user decision): subclass instead of reopening, refine to extend, freeze plain-Ruby exports (never Active Record classes). A Box reads a builtin's prime definition live until its first write.
- On 4.0.7 code required into `Ruby::Box.master` is inherited by later Boxes (shared objects, Box-local reopens), despite Ruby's docs saying no code runs there. Treat it as unsupported: only `examples/master_prelude` uses it, never the library, until Ruby supports template Boxes (user decision). Upstream proposals ask only for an official template API; Master must stay clean, so never propose a writable Master.
- Prefer raising the minimum Ruby/RubyGems/Bundler version over carrying workarounds for older releases (user decision).
- Upstream changes must be strictly necessary; do not promote historical Ruby 4.0.5 findings without current reproduction.
- Never push. Make local commits only; the user handles pushes.

## Working rules

- Everything should have tests. Write tests for new behaviour, run targeted tests as you go, and `bundle exec rake` before finishing. The test and example tasks set `RUBY_BOX=1` themselves.
- If you only changed an example, run that example during iteration and the full suite before finishing.
- Run `bundle exec rake format` after every change.
- Run `bundle exec rake rubocop` before finishing, and keep it passing for examples too.
- Keep implementation and docs concise.
- Do not over-engineer.
- Comment important lines in examples so readers can see the carton, export, and bundle boundaries at a glance.
- Never use thread local variables in implementation.
- Always review https://docs.ruby-lang.org/en/4.0/Ruby/Box.html on how `Ruby::Box` works.
- For box/gem/Bundler/RubyGems work, always re-read `docs/internals/how-boxes-work.md` and `docs/internals/how-gems-work.md` before changing code.
- Read `docs/internals/upstream.md` whenever upstream implications are relevant, and update it when plans or findings change.
- Never bump the version or publish the gem.
- When multiple implementation choices are viable, present a menu with your recommendation.
- When grilling, name the proposed new domain term before asking each question.
- Tackle each prompt systematically, keep logical changes separate, and commit each logical step independently with commit messages that explain what changed and why, not terse one-liners.
- Never push; the user will do that.

## Docs

- Keep `README.md`, `docs/usage.md`, `docs/design.md`, `docs/todo.md`, `docs/internals/how-gems-work.md`, `docs/internals/how-boxes-work.md`, `docs/internals/upstream.md`, `AGENTS.md`, and example READMEs up to date when behavior, workflow, findings, or upstream plans change.
- Keep `CHANGELOG.md` up to date under the `Unreleased` section whenever user-facing behavior changes.
- Keep the root `README.md` minimal; move detail into focused docs.
- Put future work, open questions, and upstream ideas in `docs/todo.md`.
- Update `AGENTS.md` whenever the user gives durable project guidance or you discover stable context worth remembering.
- Use `AGENTS.md` as a concise memory bank, not a changelog.

## Commands

- `bundle exec rake` - full suite (tests/examples set `RUBY_BOX=1`)
- `bundle exec rake test` - unit tests only
- `bundle exec rake example:minimal` - minimal example
- `bundle exec rake example:gems` - manual RubyGems example
- `bundle exec rake example:bundler` - per-Carton Bundler example
- `bundle exec rake example:rails_in_main` - Rails app with a Zeitwerk Carton component
- `bundle exec rake example:master_prelude` - optional unsupported hack: a prelude loaded into the Master Box
- `bundle exec rake example:rails_in_cartons` - Rails loaded once in a framework Carton; domain Cartons hold models and controllers
- `bundle exec rake rubocop` - lint code
- `bundle exec rake format` - format code
- Prefer `mise x ruby@4.0.7 -- ...` when the shell default Ruby is older than the package baseline.

## Agent skills

### Issue tracker

GitHub Issues (`gh` CLI); external PRs are also a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical names: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.
