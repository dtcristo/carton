# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'billing'
  spec.version = '0.1.0'
  spec.summary = 'Billing domain logic, imported by the Rails app as a Carton'
  spec.authors = ['Carton']
  spec.files = Dir['lib/**/*.rb']
  spec.required_ruby_version = '>= 4.0.7'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.add_dependency 'carton'
  spec.add_dependency 'customers', '= 0.1.0'
  spec.add_dependency 'zeitwerk'
end
