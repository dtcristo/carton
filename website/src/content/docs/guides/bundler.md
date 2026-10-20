---
title: Gems and Bundler
description: Give a Carton its own bundle, import gems as Gem Cartons, and organise a monorepo of path gems.
sidebar:
  order: 7
---

Carton works with or without Bundler. Each Box has its own RubyGems state, so a Carton's gems never leak into its importer.

## A Carton's own bundle

A Carton that needs its own gems sets up a Carton Bundle, from its own Gemfile, in its Entrypoint. Other Cartons need no setup.

```ruby
# cartons/math_helper/lib/math_helper.rb
Carton.setup_bundle # uses cartons/math_helper/Gemfile, only in this Box

require 'bigdecimal' # this Carton's locked version

export version: BigDecimal::VERSION
```

[`Carton.setup_bundle`](/reference/carton/#cartonsetup_bundle) works like `Bundler.setup`, and the top-level app uses the same line. `RUBY_BOX=1 bundle exec ruby main.rb` also works.

## `ENV`

`ENV` is shared by the whole process. `setup_bundle` points `BUNDLE_GEMFILE` at the Carton's Gemfile while Bundler sets up, then restores all of `ENV`.

- While `setup_bundle` runs, other threads can see the Carton's `BUNDLE_GEMFILE` and Bundler's exported variables. Call it while booting, before starting threads that read `ENV`.
- Subprocesses never inherit a Carton's bundle, including ones the Carton starts. Wrap a subprocess that needs it in `bundle exec`, or pass it `BUNDLE_GEMFILE`.

## Gem Cartons

Importing a file from a gem the importer has activated, such as a path gem in the app's Gemfile, activates that gem and its runtime dependencies in the Carton's Box at the importer's versions. The gem needs no Gemfile of its own:

```ruby title="Gemfile"
gem 'bigdecimal', '3.3.1'
gem 'pricing', path: 'pricing'
```

```ruby
# main.rb
Carton.setup_bundle
Pricing = import 'pricing' # pricing's require 'bigdecimal' gets 3.3.1
```

- A Gem Carton loads once per process, so its First Importer fixes its gem versions. A later importer that activates or locks a different version of one of them raises `Carton::ImportError` naming the gem and both versions.
- If the importer ran Bundler setup, the Gem Carton's Box is restricted to that bundle, as `Bundler.setup` restricts the Main Box. Every locked gem loads at its locked version, and a gem outside the lockfile raises `LoadError`.
- Without Bundler, only declared dependencies the importer activated are shared. Anything else falls back to RubyGems picking the newest installed version inside the Box.
- If the Gem Carton also calls `setup_bundle`, its Gemfile must agree with the importer's versions, or Bundler raises `Gem::LoadError`.

Because a bundled importer exposes its whole lockfile, a Gem Carton can load a gem it never declared and still work, until it is installed somewhere without that gem. [`carton check`](/reference/cli/#carton-check) reports each Undeclared Gem, so the gemspec stays an accurate manifest.

## Monorepos

To split an app into Cartons, make each one a path gem in one Gemfile and import it by gem name. Each gemspec lists the Carton's dependencies, and the app's lockfile pins every version. See the [monorepo example](https://github.com/dtcristo/carton/tree/main/examples/monorepo).

## Different versions side by side

Plain Ruby cannot load two versions of one gem in a process. Two Cartons with their own bundles can, which suits plugin hosts whose plugins disagree. See the [plugins example](https://github.com/dtcristo/carton/tree/main/examples/plugins).
