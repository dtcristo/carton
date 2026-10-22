# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'billing'
  spec.version = '0.1.0'
  spec.summary = 'Billing domain: isolated Rails Engine'
  spec.authors = ['Carton']
  spec.files =
    Dir['{app,lib,config,db}/**/*'].select { |path| File.file?(path) }
  spec.add_dependency 'carton'
  spec.add_dependency 'customers'
  spec.add_dependency 'framework'
  spec.add_dependency 'zeitwerk'
end
