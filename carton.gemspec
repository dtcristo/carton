# frozen_string_literal: true

require_relative 'lib/carton/version'

Gem::Specification.new do |spec|
  spec.name = 'carton'
  spec.version = Carton::VERSION
  spec.authors = ['David Cristofaro']
  spec.email = ['david@dtcristo.com']

  spec.summary = 'Real boundaries for Ruby'
  spec.description =
    'Ruby apps draw boundaries with folders and namespaces. Ruby ignores ' \
      'them. Carton makes them real. Split your app into Cartons with ' \
      'explicit imports and exports. Each has its own dependencies and runs ' \
      'in a separate Ruby::Box, so Ruby enforces the boundaries at runtime. ' \
      'Only what a Carton exports is reachable, monkey patches stay where ' \
      'they are made, and two Cartons can use different versions of the ' \
      'same gem. No manifest needed. Requires Ruby 4.0.7+.'
  spec.homepage = 'https://carton.dtcristo.com'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0.7'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/dtcristo/carton'
  spec.metadata[
    'changelog_uri'
  ] = 'https://github.com/dtcristo/carton/blob/main/CHANGELOG.md'

  # An explicit list, so packaging does not depend on git or ship examples.
  # The carton command ships in carton-tools.
  spec.files =
    Dir.glob(%w[lib/**/*.rb sig/**/*.rbs], base: __dir__) +
      %w[CHANGELOG.md LICENSE.txt README.md]
  spec.require_paths = ['lib']
end
