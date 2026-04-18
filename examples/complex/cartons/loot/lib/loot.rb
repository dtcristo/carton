# frozen_string_literal: true

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

Plans = import File.expand_path('../../quest/lib/quest', __dir__)
Environment = import 'dotenv'

dotenv_version = Gem.loaded_specs.fetch('dotenv').version.to_s
config = Environment.fetch(:Dotenv).parse(File.expand_path('../.env', __dir__))
legacy_message =
  "#{config.fetch('MESSAGE')} | quest says: #{Plans.fetch :summary}"

export legacy_message:, DOTENV_VERSION: dotenv_version
