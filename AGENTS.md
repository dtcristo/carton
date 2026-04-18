# Agents

Guidance and memory for agents working on this repo.

## Memory bank

- Goal: make Carton feel like part of Ruby: built-in, simple, streamlined, and not verbose.
- Prefer simpler implementation over complexity.
- Keep the public API small and Ruby-like.
- Keep the library feeling native to Ruby; explicit setup is fine when it keeps behavior simple and unsurprising.
- The project should work with or without Bundler.
- A package in this system is called a carton, though docs can still use "package" in plain English when it reads better.
- Ruby::Box boxes start from root-box load paths/loaded features; prefer explicit caller-managed load-path setup over automatic inheritance.
- `$LOAD_PATH` is box-local, but `Gem.loaded_specs` is shared across boxes in practice, so conflicting bundle activation still collides there.
- Duplicating `Gem.loaded_specs` inside a box isolates a single bundled import from root state, but conflicting bundles still fail because Bundler also rewrites shared RubyGems entrypoints/spec state such as `Gem::Specification.all`.
- Bundler itself can already load per box; the hard parts are root-loaded RubyGems methods/state and the Ruby 4.0.2 teardown crash when Bundler is required in multiple boxes.
- Upstream changes must be strictly necessary; prototype a Carton-side monkey patch first and only upstream the smallest supportable RubyGems/Ruby changes afterward.
- Never push. Make local commits only; the user handles pushes.

## Working rules

- Everything should have tests. Write tests for new behaviour, run targeted tests as you go, and `RUBY_BOX=1 bundle exec rake` before finishing.
- If you only changed an example, run that example during iteration and the full suite before finishing.
- Run `bundle exec rake format` after every change.
- Keep implementation and docs concise.
- Do not over-engineer.
- Never use thread local variables in implementation.
- Always review https://docs.ruby-lang.org/en/4.0/Ruby/Box.html on how `Ruby::Box` works.
- For box/gem/Bundler/RubyGems work, always re-read `docs/HOW_BOXES_WORK.md` and `docs/HOW_GEMS_WORK.md` before changing code.
- Read `docs/RUBY_UPSTREAM.md` and `docs/RUBYGEMS_UPSTREAM.md` whenever upstream implications are relevant, and update them when plans or findings change.
- Never bump the version or publish the gem.
- When multiple implementation choices are viable, present a menu with your recommendation.
- Tackle each prompt systematically, keep logical changes separate, and commit each logical step independently with descriptive messages and the required Co-authored-by trailer.
- Never push; the user will do that.

## Docs

- Keep `README.md`, `docs/USAGE.md`, `docs/DESIGN.md`, `docs/TODO.md`, `docs/HOW_GEMS_WORK.md`, `docs/HOW_BOXES_WORK.md`, `docs/RUBYGEMS_UPSTREAM.md`, `docs/RUBY_UPSTREAM.md`, `AGENTS.md`, and example READMEs up to date when behavior, workflow, findings, or upstream plans change.
- Keep the root `README.md` minimal; move detail into focused docs.
- Put future work, open questions, and upstream ideas in `docs/TODO.md`.
- Update `AGENTS.md` whenever the user gives durable project guidance or you discover stable context worth remembering.
- Use `AGENTS.md` as a concise memory bank, not a changelog.

## Commands

- `RUBY_BOX=1 bundle exec rake` - full suite
- `RUBY_BOX=1 bundle exec rake test` - unit tests only
- `RUBY_BOX=1 bundle exec rake example:minimal` - minimal example
- `RUBY_BOX=1 bundle exec rake example:complex` - complex example
- `bundle exec rake format` - format code
