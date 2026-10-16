# frozen_string_literal: true

require 'bigdecimal'

export bigdecimal_version: BigDecimal::VERSION,
       activated: Gem.loaded_specs['bigdecimal']&.version&.to_s
