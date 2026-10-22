# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'framework'
  spec.version = '0.1.0'
  spec.summary = 'Loads Hanami, Dry, and Rom once and shares their APIs'
  spec.authors = ['Carton']
  spec.files = Dir['lib/**/*.rb']
  spec.add_dependency 'carton'
  spec.add_dependency 'dry-operation'
  spec.add_dependency 'dry-validation'
  spec.add_dependency 'hanami'
  spec.add_dependency 'hanami-db'
  spec.add_dependency 'sqlite3'
end
