# frozen_string_literal: true

require_relative 'lib/carton/version'

Gem::Specification.new do |spec|
  spec.name = 'carton'
  spec.version = Carton::VERSION
  spec.authors = ['David Cristofaro']
  spec.email = ['david@dtcristo.com']

  spec.summary = 'Easily box your Ruby'
  spec.description =
    'Carton is a thin wrapper around Ruby::Box for safe, ergonomic modularization ' \
      'in Ruby 4.0.7+. It gives you imports and exports that work like ES Modules ' \
      'while still feeling like Ruby. Each carton can isolate constants, gems ' \
      'and monkey patches behind a small public API, so large apps can keep ' \
      'clear boundaries.'
  spec.homepage = 'https://github.com/dtcristo/carton'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0.7'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata[
    'changelog_uri'
  ] = 'https://github.com/dtcristo/carton/blob/main/CHANGELOG.md'

  # An explicit list, so packaging does not depend on git or ship examples.
  spec.files =
    Dir.glob(%w[lib/**/*.rb sig/**/*.rbs], base: __dir__) +
      %w[CHANGELOG.md LICENSE.txt README.md]
  spec.require_paths = ['lib']
end
