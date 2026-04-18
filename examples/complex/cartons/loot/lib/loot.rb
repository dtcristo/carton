# frozen_string_literal: true

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

DotenvBox = import 'dotenv'
Plans = import_relative '../../quest/lib/quest'

config = DotenvBox.fetch(:Dotenv).parse(File.expand_path('../.env', __dir__))
legacy_message =
  "#{config.fetch('MESSAGE')} | quest says: #{Plans.fetch :summary}"

DOTENV_VERSION = Gem.loaded_specs.fetch('dotenv').version.to_s

export legacy_message:, DOTENV_VERSION:
