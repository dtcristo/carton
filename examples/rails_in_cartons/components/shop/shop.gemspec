# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'shop'
  spec.version = '0.1.0'
  spec.summary = 'Assembles the Rails application from domain cartons'
  spec.authors = ['Carton']
  spec.files = Dir['{app,lib}/**/*.rb']
  spec.add_dependency 'customers'
  spec.add_dependency 'framework'
  spec.add_dependency 'logger'
  spec.add_dependency 'orders'
end
