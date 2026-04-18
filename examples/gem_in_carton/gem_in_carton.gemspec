# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'gem_in_carton'
  spec.version = '0.1.0'
  spec.summary = 'Minimal carton-aware gem example'
  spec.authors = ['Carton']
  spec.files = ['lib/gem_in_carton.rb']
  spec.require_paths = ['lib']

  spec.add_dependency 'bigdecimal', '= 2.0.3'
  spec.add_dependency 'carton'
end
