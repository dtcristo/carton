# frozen_string_literal: true

error =
  begin
    Carton.setup_bundle
    nil
  rescue StandardError => e
    e.class.name
  end

export error:,
       env_gemfile: ENV['BUNDLE_GEMFILE'],
       env_lockfile: ENV['BUNDLE_LOCKFILE']
