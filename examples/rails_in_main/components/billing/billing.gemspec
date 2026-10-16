# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'billing'
  spec.version = '0.1.0'
  spec.summary = 'Billing domain logic, imported by the Rails app as a Carton'
  spec.authors = ['Carton']
  spec.files = Dir['lib/**/*.rb']
  spec.add_dependency 'zeitwerk'
end
