---
title: Gems and Bundler
description: Give a Carton its own bundle, import gems as Gem Cartons, and organise a monorepo of path gems.
sidebar:
  order: 7
---

Carton works with or without Bundler. Each Box has its own RubyGems state, so a Carton's gems never leak into its Importer.

## A Carton's own bundle

A Carton that needs its own gems sets up a Carton Bundle, from its own Gemfile, in its Entrypoint. Other Cartons need no setup.

```ruby
# cartons/crm_client/lib/crm_client.rb
Carton.setup_bundle # uses cartons/crm_client/Gemfile, only in this Box

require 'faraday' # this Carton's locked version

export version: Faraday::VERSION
```

[`Carton.setup_bundle`](/reference/carton/#setup_bundle) works like `Bundler.setup`, and the top-level app uses the same line:

- Pass groups to set up only those, such as `Carton.setup_bundle(:default, :test)`.
- It searches upward from the calling file for `gems.rb` or `Gemfile`. Pass `gemfile:`, relative to the calling file, to choose one.
- It raises `Carton::GemfileNotFound` when there is no Gemfile, and Bundler errors raise instead of exiting.

`RUBY_BOX=1 bundle exec ruby main.rb` also works, including when the Gemfile evaluates a gemspec.

## `ENV`

`ENV` is shared by the whole process. Bundler reads its Gemfile from `BUNDLE_GEMFILE` and exports variables such as `RUBYOPT` for subprocesses, so `setup_bundle` points `BUNDLE_GEMFILE` at the Carton's Gemfile while Bundler sets up, then restores all of `ENV`. Bundler remembers the Gemfile it chose, so a later `Bundler.require` in the same Carton still uses it.

- While `setup_bundle` runs, other threads can see the Carton's `BUNDLE_GEMFILE` and Bundler's exported variables. Call it while booting, before starting threads that read `ENV`.
- Subprocesses never inherit a Carton's bundle, including ones the Carton starts. Wrap a subprocess that needs it in `bundle exec`, or pass it `BUNDLE_GEMFILE`.

## Gem Cartons

Importing a file from a gem the Importer has activated, such as a path gem in the app's Gemfile, activates that gem and its runtime dependencies in the Carton's Box at the Importer's versions. The gem needs no Gemfile of its own, but its Entrypoint must explicitly export a value. For a gem without an export, require it inside a Carton and explicitly export the value Importers need:

```ruby title="Gemfile"
gem 'faraday', '2.15.0'
gem 'shipping', path: 'shipping'
```

```ruby
# main.rb
Carton.setup_bundle
Shipping = import 'shipping' # shipping's require 'faraday' gets 2.15.0
```

- A Gem Carton loads once per process, so its First Importer fixes its gem versions: its Gem Closure, plus any locked gem it has loaded without declaring, including one required lazily after its import. A later Importer that activates or locks a different version of one of those raises `Carton::ImportError` naming the gem and both versions, instead of sharing a Carton built against other versions. A gem the Carton first loads after that later import cannot be checked.
- Default gems in the Gem Closure keep the Importer's activated version too, so a newer installed version does not replace it inside the Carton.
- If the Importer ran Bundler setup (`Carton.setup_bundle`, `bundler/setup`, or `bundle exec`), the Gem Carton's Box is restricted to that bundle, as `Bundler.setup` restricts the Main Box. Every locked gem loads at its locked version, even one the gemspec forgot to declare, and a gem outside the lockfile raises `LoadError`.
- Without Bundler, only declared dependencies the Importer activated are shared. Anything else falls back to RubyGems picking the newest installed version inside the Box.
- If the Gem Carton also calls `setup_bundle`, its Gemfile must agree with the Importer's versions, or Bundler raises `Gem::LoadError`.

Because a bundled Importer exposes its whole lockfile, a Gem Carton can load a gem it never declared and still work, until it is installed somewhere without that gem. [`carton check`](/reference/cli/check/) reports each Undeclared Gem, so the gemspec stays an accurate list of dependencies; run it under `bundle exec` so it sees the bundle's gems. Default gems and Carton itself need no declaration.

## Monorepos

To split an app into Cartons, make each one a path gem in one Gemfile and import it by gem name. Each gemspec lists the Carton's dependencies, and the app's lockfile pins every version. See the [monorepo example](/guides/examples/monorepo/).

## Different versions side by side

Plain Ruby cannot load two versions of one gem in a process. Two Cartons with their own bundles can, which suits plugin hosts whose plugins disagree. See the [plugins example](/guides/examples/plugins/).

The repository's [How gems work](https://github.com/dtcristo/carton/blob/main/docs/internals/how-gems-work.md) has the runtime background.
