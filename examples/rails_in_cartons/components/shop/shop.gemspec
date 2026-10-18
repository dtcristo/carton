# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'shop'
  spec.version = '0.1.0'
  spec.summary = 'Assembles the Rails application from domain cartons'
  spec.authors = ['Carton']
  spec.files = Dir['{app,lib}/**/*.rb', 'config/**/*.yml']
  spec.required_ruby_version = '>= 4.0.7'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.add_dependency 'carton'
  spec.add_dependency 'customers'
  spec.add_dependency 'framework'
  spec.add_dependency 'logger'
  spec.add_dependency 'orders'
end
