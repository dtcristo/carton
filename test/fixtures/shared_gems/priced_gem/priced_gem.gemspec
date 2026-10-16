# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'priced_gem'
  spec.version = '0.1.0'
  spec.summary = 'Path gem Carton whose dependency is locked by the app'
  spec.authors = ['Carton']
  spec.files = ['lib/priced_gem.rb']
  spec.add_dependency 'bigdecimal'
end
