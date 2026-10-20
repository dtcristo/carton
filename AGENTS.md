# Agents

## North Star

Carton is the package system Ruby has always needed: real boundaries for Ruby code, enforced while it runs. A Carton has a private interior, a declared public surface, its own dependencies and gem versions, and the shape of a gem, so it can leave the app as one. Weigh every change by whether it moves Carton toward that, for apps of any size; [design.md](docs/design.md#how-close-carton-is) tracks the gaps.

## Principles

- Make Carton feel built into Ruby: small, Ruby-like API; simple over clever.
- Works with or without Bundler; keep Bundler/RubyGems support separate from the core runtime.
- Target Ruby 4.0.7+ and Bundler 4.0.20+. Raise minimum versions instead of carrying workarounds.
- Upstream changes must be strictly necessary and reproduce on current releases.

## Decisions

- Importers never get another Carton's Box; Bare Cartons return `Carton::Namespace`.
- A Carton is an Entrypoint `x.rb` plus its Interior, the `x/` directory beside it (gem `lib/` shape, Zeitwerk namespaces); no gemspec or manifest required (user decision). Interior files cannot be imported; the outermost Entrypoint wins.
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
- Carton keeps Master Box clean; direct writes belong only in unsupported spikes. Upstream asks only for an official template Box API.

## Rules

- Keep supported integration examples under `examples/` and private-runtime or unsupported experiments under `spikes/`; both Rails examples remain examples. Run `bundle exec rake spikes` for the CI-covered experiments.
- For shared dependency or template Box work, read [the Shared Gems spike](spikes/shared_gems/results.md): method transplantation works, but normal gem activation and loading remain incompatible, and Ruby 4.0.7 visibility-only builtin changes can leak to Master.

- For Rails reloading work, read [the spike's findings and limits](spikes/rails_reloading/README.md). Its private runtime inspection is experimental; ordinary apps still restart on change.
- Before Box/gem/Bundler work, read `docs/internals/how-boxes-work.md` and `docs/internals/how-gems-work.md`; read `docs/internals/upstream.md` for upstream questions.
- Test everything. Run `bundle exec rake format` after changes; `bundle exec rake` (tests, rubocop, examples) before finishing.
- Update the relevant docs, `CHANGELOG.md` (Unreleased), and this file when behavior or durable guidance changes. Website-only changes (`website/`) get no changelog entry.
- End each changelog item and release summary with the PRs that introduced its changes, before the final period: `- Added foo (#123).` Include multiple PRs when an item combines changes, and add the number before merging. Historical changes made outside a PR link to their introducing commit instead.
- Use the matching section of the merged `CHANGELOG.md` as the source for GitHub release notes. Keep Pending items in Unreleased until their implementation reaches `main`, and omit them from release notes.
- The website in `website/` (Astro + Starlight, Node pinned in `.mise.toml`) is the user-facing guide and reference; `docs/` is for contributors. When public behavior changes, update both `docs/usage.md` and the matching pages under `website/src/content/docs/`, and check the reference against `sig/carton.rbs`. Run `npm run build` in `website/` after site changes; it checks every internal link. Never deploy it by hand.
- Keep `CONTEXT.md` current: when a domain concept is added, renamed, or redefined, update it in the same change. Keep code (identifiers, comments, test names, messages) and docs in step with it, using its terms and never the ones it lists under _Avoid_.
- Comment examples so Carton, export, and bundle boundaries are visible.
- Don't hard-wrap Markdown: write each paragraph, list item, and blockquote on one line.
- To test which Gemfile was selected, check `Bundler.root` (memoized), not `Bundler.default_gemfile` (rereads `ENV`).
- No thread-local variables.
- Commit each logical step separately with explanatory messages.
- Never push, bump the version, or publish the gem.
- Offer a menu with a recommendation when several designs are viable.
- Use `mise x ruby@4.0.7 -- ...` if the shell Ruby is older.

## Agent skills

- Issues: GitHub via `gh`; see `docs/agents/issue-tracker.md` and `docs/agents/triage-labels.md`.
- Domain: `CONTEXT.md` and `docs/adr/`; see `docs/agents/domain.md`.
