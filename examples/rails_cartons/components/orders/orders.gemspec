# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'orders'
  spec.version = '0.1.0'
  spec.summary = 'Orders domain: model and controller'
  spec.authors = ['Carton']
  spec.files = Dir['{app,lib}/**/*.rb']
  spec.add_dependency 'customers'
  spec.add_dependency 'framework'
  spec.add_dependency 'zeitwerk'
end
