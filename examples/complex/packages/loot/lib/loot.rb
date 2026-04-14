# frozen_string_literal: true

require 'json'
require 'open3'
require 'rbconfig'

Plans = import 'quest'

dotenv_payload =
  begin
    env_file = File.expand_path('../.env', __dir__)
    gemfile = File.expand_path('../Gemfile', __dir__)
    script = <<~'RUBY'
      require 'json'
      require 'bundler/setup'
      require 'dotenv'

      config = Dotenv.parse(ARGV.fetch(0))
      version = Gem.loaded_specs.fetch('dotenv').version.to_s
      puts JSON.generate(version:, config:)
    RUBY

    output, status =
      Open3.capture2e(
        { 'BUNDLE_GEMFILE' => gemfile },
        RbConfig.ruby,
        '-e',
        script,
        env_file,
      )

    unless status.success?
      raise RuntimeError, "failed to load loot dotenv bundle: #{output}"
    end

    JSON.parse output
  end

dotenv_version = dotenv_payload.fetch 'version'
legacy_message =
  "#{dotenv_payload.fetch('config').fetch('MESSAGE')} | quest says: #{Plans.fetch :summary}"

export legacy_message:, DOTENV_VERSION: dotenv_version
