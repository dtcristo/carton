# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'shop'
  spec.version = '0.1.0'
  spec.summary = 'Assembles the Rails application from domain cartons'
  spec.authors = ['Carton']
  paths = %w[lib/**/* config/**/* config.ru Rakefile bin/rails]
  spec.files = Dir.glob(paths).select { |path| File.file?(path) }
  spec.required_ruby_version = '>= 4.0.7'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.add_dependency 'billing'
  spec.add_dependency 'carton'
  spec.add_dependency 'customers'
  spec.add_dependency 'framework'
  spec.add_dependency 'logger'
  spec.add_dependency 'puma', '~> 8.0'
end
