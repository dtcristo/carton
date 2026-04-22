# frozen_string_literal: true

Gem::Specification.new do |spec|
  spec.name = 'cartoned_gem'
  spec.version = '0.1.0'
  spec.summary = 'Minimal invoice helper gem for the bundler example'
  spec.authors = ['Carton']
  spec.files = ['lib/cartoned_gem.rb']
  spec.require_paths = ['lib']
  spec.required_ruby_version = '>= 4.0.2'

  spec.add_dependency 'carton'
  spec.metadata['rubygems_mfa_required'] = 'true'
end
