# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'framework'
  spec.version = '0.1.0'
  spec.summary = 'Loads Rails once and shares its base classes'
  spec.authors = ['Carton']
  spec.files = Dir['{app,lib}/**/*.rb']
  spec.add_dependency 'actionpack'
  spec.add_dependency 'activerecord'
  spec.add_dependency 'carton'
  spec.add_dependency 'railties'
  spec.add_dependency 'sqlite3'
end
