# frozen_string_literal: true

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }
require 'dotenv'

module Adventure
  CONFIG = Dotenv.parse(File.expand_path('../.env', __dir__))
  DOTENV_VERSION = Gem.loaded_specs.fetch('dotenv').version.to_s

  def self.banner = CONFIG.fetch('BANNER')

  def self.dotenv_version = DOTENV_VERSION
end

export_default Adventure
