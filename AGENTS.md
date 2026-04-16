# Agents

Guidance and memory for agents working on this repo.

## Memory bank

- Goal: make Carton feel like part of Ruby: built-in, simple, streamlined, and not verbose.
- Prefer simpler implementation over complexity.
- Keep the public API small and Ruby-like.
- The project should work with or without Bundler.
- A package in this system is called a carton, though docs can still use "package" in plain English when it reads better.
- Current reliable bundled-carton pattern: use `Carton.with_bundle(gemfile) { import ... }` for the entry import that should activate a carton-local bundle.
- Conflicting bundles still need a subprocess workaround today.
- Ruby::Box boxes start from root-box load paths/loaded features, so Carton must copy parent non-gem load paths forward itself.
- `$LOAD_PATH` is box-local, but `Gem.loaded_specs` is shared across boxes in practice, so conflicting bundle activation still collides there.
- Duplicating `Gem.loaded_specs` inside a box isolates a single bundled import from root state, but conflicting bundles still fail because Bundler also rewrites shared RubyGems entrypoints/spec state such as `Gem::Specification.all`.
- Never push. Make local commits only; the user handles pushes.

## Working rules

- Everything should have tests. Write tests for new behaviour, run targeted tests as you go, and `RUBY_BOX=1 bundle exec rake` before finishing.
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
