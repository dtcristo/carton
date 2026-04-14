# Agents

Guidance and memory for agents working on this repo.

## Memory bank

- Goal: keep Package small, simple, and focused on isolated `Ruby::Box` imports/exports.
- Prefer the smallest clear implementation over cleverness or extra abstraction.
- Keep the public API minimal; example-only glue can live in examples while designs are still settling.
- Current reliable Bundler pattern: set `BUNDLE_GEMFILE` around the `import` that loads a bundled package.
- Conflicting bundles still need a subprocess workaround today.
- Never push. Make local commits only; the user handles pushes.

## Working rules

- Write tests for new behaviour; run targeted tests as you go and `RUBY_BOX=1 bundle exec rake` before finishing.
- If you only changed an example, run that example during iteration and the full suite before finishing.
- Run `bundle exec rake format` after every change.
- Keep implementation and docs concise.
- Do not over-engineer.
- Never use thread local variables in implementation.
- Always review https://docs.ruby-lang.org/en/4.0/Ruby/Box.html on how `Ruby::Box` works.
- Never bump the version or publish the gem.
- When multiple implementation choices are viable, present a menu with your recommendation.
- Commit as you go with descriptive messages and the required Co-authored-by trailer.
- Never push; the user will do that.

## Docs

- Keep `README.md`, `USAGE.md`, `DESIGN.md`, `TODO.md`, `AGENTS.md`, and example READMEs up to date when behavior, workflow, or plans change.
- Keep the root `README.md` minimal; move detail into focused docs.
- Put future work, open questions, and upstream ideas in `TODO.md`.
- Update `AGENTS.md` whenever the user gives durable project guidance or you discover stable context worth remembering.
- Use `AGENTS.md` as a concise memory bank, not a changelog.

## Commands

- `RUBY_BOX=1 bundle exec rake` - full suite
- `RUBY_BOX=1 bundle exec rake test` - unit tests only
- `RUBY_BOX=1 bundle exec rake example:minimal` - minimal example
- `RUBY_BOX=1 bundle exec rake example:complex` - complex example
- `bundle exec rake format` - format code
