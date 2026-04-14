# frozen_string_literal: true

require 'dotenv'

module Adventure
  CONFIG = Dotenv.parse(File.expand_path('../.env', __dir__))
  def self.banner = CONFIG.fetch('BANNER')

  def self.dotenv_version = Gem.loaded_specs.fetch('dotenv').version.to_s
end

export Adventure
