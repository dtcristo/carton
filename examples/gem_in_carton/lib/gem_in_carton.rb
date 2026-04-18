# frozen_string_literal: true

require 'carton'

Carton.bootstrap_rubygems!

spec = Gem::Specification.find_by_name('bigdecimal', '= 3.3.1')
spec.full_require_paths.reverse_each do |path|
  $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
end
require 'bigdecimal'

module GemInCarton
  VERSION = '0.1.0'
end

export version: GemInCarton::VERSION, bigdecimal_version: BigDecimal::VERSION
