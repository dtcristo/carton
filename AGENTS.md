# Agents

## Principles

- Make Carton feel built into Ruby: small, Ruby-like API; simple over clever.
- Works with or without Bundler; keep Bundler/RubyGems support separate from the core runtime.
- Target Ruby 4.0.7+ and Bundler 4.0.23+. Raise minimum versions instead of carrying workarounds.
- Upstream changes must be strictly necessary and reproduce on current releases.

## Decisions

- Importers never get another Carton's Box; Bare Cartons return `Carton::Namespace`.
- A Carton is an Entrypoint `x.rb` plus the `x/` directory beside it (gem `lib/` shape, Zeitwerk namespaces); no gemspec or manifest required (user decision). Files inside a Carton cannot be imported; the outermost Entrypoint wins.
- Imports are cached process-wide by Entrypoint real path.
- `Carton::Box` wraps a plain `Ruby::Box`; never subclass `Ruby::Box` (autoloads would load in the importer's Box).
- Only the imported Entrypoint's `export` counts; elsewhere it is inert.
- `export` takes one value, once per Entrypoint; Named Exports are gone, since a Ruby module is already a namespace (user decision). Keywords export a plain Hash, and a Symbol raises `ExportError`.
- `import` returns the exported value itself, never a wrapper.
- Use Ruby's `private_constant` for visibility; Carton adds none.
- A Bare Carton helper that would hide a `Carton::Namespace` method raises `ExportError`.
- Shared-class reopening risk is documented only (subclass, refine, freeze).
- No `carton run` or `carton exec`: `RUBY_BOX=1` is the interface (user decision). The `carton` command only reads code (Prism).
- Two gems, released together at one version: `carton` is the runtime only, with no dependencies and no executable, since every gem built on Carton depends on it; `carton-tools` (`carton-tools/`, `Carton::Tools`) holds the `carton` command and static analysis, depends on exactly the same `carton`, and may use its internals (user decision).
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
