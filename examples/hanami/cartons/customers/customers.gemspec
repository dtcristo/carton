# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'customers'
  spec.version = '0.1.0'
  spec.summary =
    'Customers domain: Hanami slice with Dry contracts and ROM repos'
  spec.authors = ['Carton']
  spec.files = Dir['lib/**/*'].select { |path| File.file?(path) }
  spec.add_dependency 'carton'
  spec.add_dependency 'framework'
  spec.add_dependency 'zeitwerk'
end
