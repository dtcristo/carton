# frozen_string_literal: true

Carton.bootstrap_rubygems!
Carton.with_bundle { require 'bundler/setup' }

require 'bigdecimal'

module Adventure
  VERSION = BigDecimal::VERSION

  def self.version = VERSION
end

export_default Adventure
