# frozen_string_literal: true

require_relative 'lib/carton/version'

Gem::Specification.new do |spec|
  spec.name = 'carton'
  spec.version = Carton::VERSION
  spec.authors = ['David Cristofaro']
  spec.email = ['david@dtcristo.com']

  spec.summary = 'Easily box your Ruby'
  spec.description =
    'Split a Ruby app into gem-sized units that import and export like ' \
      'modules. Each Carton runs in its own Ruby::Box, so two parts of one app ' \
      'can use different versions of the same gem, monkey patches stay where ' \
      'they are made, and only what a Carton exports is reachable. No manifest ' \
      'needed. Requires Ruby 4.0.7+.'
  spec.homepage = 'https://github.com/dtcristo/carton'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0.7'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata[
    'changelog_uri'
  ] = 'https://github.com/dtcristo/carton/blob/main/CHANGELOG.md'

  # An explicit list, so packaging does not depend on git or ship examples.
  spec.files =
    Dir.glob(%w[lib/**/*.rb sig/**/*.rbs], base: __dir__) +
      %w[CHANGELOG.md LICENSE.txt README.md]
  spec.require_paths = ['lib']
end
