# frozen_string_literal: true

selected = nil
selected_lockfile = nil

Carton.with_bundle do
  selected = ENV['BUNDLE_GEMFILE']
  selected_lockfile = ENV['BUNDLE_LOCKFILE']
end

export selected:,
       selected_lockfile:,
       restored: ENV['BUNDLE_GEMFILE'],
       restored_lockfile: ENV['BUNDLE_LOCKFILE']
