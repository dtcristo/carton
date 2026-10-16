# frozen_string_literal: true

Carton.setup_bundle

export selected_root: Bundler.root.to_s,
       restored: ENV['BUNDLE_GEMFILE'],
       restored_lockfile: ENV['BUNDLE_LOCKFILE']
