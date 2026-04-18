# frozen_string_literal: true

selected = nil

Carton.with_bundle { selected = ENV['BUNDLE_GEMFILE'] }

export selected:, restored: ENV['BUNDLE_GEMFILE']
