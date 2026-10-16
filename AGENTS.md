# Agents

## Principles

- Make Carton feel built into Ruby: small, Ruby-like API; simple over clever.
- Works with or without Bundler; keep Bundler/RubyGems support separate from the core runtime.
- Target Ruby 4.0.7+ and Bundler 4.0.23+. Raise minimum versions instead of carrying workarounds.
- Upstream changes must be strictly necessary and reproduce on current releases.

## Decisions

- Importers never get another Carton's Box; Bare Cartons return `Carton::Exports`.
- Imports are cached process-wide by Entrypoint real path.
- Only the imported Entrypoint's `export` counts; elsewhere it is inert.
- `export` is repeatable; `export_default` is exclusive (once, never with `export`).
- Use Ruby's `private_constant` for visibility; Carton adds none.
- Shared-class reopening risk is documented only (subclass, refine, freeze).
- Master Box stays clean: only `examples/master_prelude` writes to it, and upstream asks only for an official template Box API.

## Rules

- Before Box/gem/Bundler work, read `docs/internals/how-boxes-work.md` and `docs/internals/how-gems-work.md`; read `docs/internals/upstream.md` for upstream questions.
- Test everything. Run `bundle exec rake format` after changes; `bundle exec rake` (tests, rubocop, examples) before finishing.
- Update the relevant docs, `CHANGELOG.md` (Unreleased), and this file when behavior or durable guidance changes.
- Comment examples so Carton, export, and bundle boundaries are visible.
- To test which Gemfile was selected, check `Bundler.root` (memoized), not `Bundler.default_gemfile` (rereads `ENV`).
- No thread-local variables.
- Commit each logical step separately with explanatory messages.
- Never push, bump the version, or publish the gem.
- Offer a menu with a recommendation when several designs are viable.
- Use `mise x ruby@4.0.7 -- ...` if the shell Ruby is older.

## Agent skills

- Issues: GitHub via `gh`; see `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md`.
- Domain: `CONTEXT.md` and `docs/adr/`; see `docs/agents/domain.md`.
