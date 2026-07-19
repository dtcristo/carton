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
- Target Ruby 4.0.6 or later: Master Box is the immutable copy source, Root Box runs bootstrap/builtins, Main Box runs the application, and Cartons run in optional Boxes.
- Optional Boxes do not inherit Root or Main state; resolve imports in the caller and carry only the required load-path entry forward.
- Ruby 4.0.6 confirms distinct RubyGems activation state, conflicting non-path bundles, and path-gem Carton imports under ordinary per-Carton Bundler setup.
- `RUBY_BOX=1 bundle exec` still fails on Ruby 4.0.6 when a Gemfile evaluates a gemspec before `Gem::Specification` is visible; keep that as upstream prelude work.
- Carton clears process-global `BUNDLER_SETUP` around optional Box construction so Master-based Boxes do not re-enter the caller's `bundler/setup`.
- Upstream changes must be strictly necessary; do not promote historical Ruby 4.0.5 findings without current reproduction.
- Never push. Make local commits only; the user handles pushes.

## Working rules

- Everything should have tests. Write tests for new behaviour, run targeted tests as you go, and `bundle exec rake` before finishing. The test and example tasks set `RUBY_BOX=1` themselves; do not wrap the outer `bundle exec` in `RUBY_BOX=1` until the gemspec prelude failure is fixed upstream.
- If you only changed an example, run that example during iteration and the full suite before finishing.
- Run `bundle exec rake format` after every change.
- Run `bundle exec rake rubocop` before finishing, and keep it passing for examples too.
- Keep implementation and docs concise.
- Do not over-engineer.
- Comment important lines in examples so readers can see the carton, export, and bundle boundaries at a glance.
- Never use thread local variables in implementation.
- Always review https://docs.ruby-lang.org/en/4.0/Ruby/Box.html on how `Ruby::Box` works.
- For box/gem/Bundler/RubyGems work, always re-read `docs/how-boxes-work.md` and `docs/how-gems-work.md` before changing code.
- Read `docs/ruby-upstream.md` and `docs/rubygems-upstream.md` whenever upstream implications are relevant, and update them when plans or findings change.
- Never bump the version or publish the gem.
- When multiple implementation choices are viable, present a menu with your recommendation.
- When grilling, name the proposed new domain term before asking each question.
- Tackle each prompt systematically, keep logical changes separate, and commit each logical step independently with commit messages that explain what changed and why, not terse one-liners.
- Never push; the user will do that.

## Docs

- Keep `README.md`, `docs/usage.md`, `docs/design.md`, `docs/todo.md`, `docs/how-gems-work.md`, `docs/how-boxes-work.md`, `docs/rubygems-upstream.md`, `docs/ruby-upstream.md`, `AGENTS.md`, and example READMEs up to date when behavior, workflow, findings, or upstream plans change.
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
- `bundle exec rake rubocop` - lint code
- `bundle exec rake format` - format code
- Prefer `mise x ruby@4.0.6 -- ...` when the shell default Ruby is older than the package baseline.

## Agent skills

### Issue tracker

GitHub Issues (`gh` CLI); external PRs are also a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

Canonical names: `needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `CONTEXT.md` + `docs/adr/`. See `docs/agents/domain.md`.
