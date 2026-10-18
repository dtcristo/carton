# frozen_string_literal: true

require_relative 'lib/carton/version'

Gem::Specification.new do |spec|
  spec.name = 'carton'
  spec.version = Carton::VERSION
  spec.authors = ['David Cristofaro']
  spec.email = ['david@dtcristo.com']

  spec.summary = 'Real boundaries for Ruby'
  spec.description =
    'The package system Ruby has been missing. Split code into Cartons that ' \
      'import and export like modules. Each Carton runs in its own Ruby::Box, ' \
      'so only what it exports is reachable, monkey patches stay where they ' \
      'are made, and two Cartons can use different versions of the same gem. ' \
      'No manifest needed. Requires Ruby 4.0.7+.'
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
    Dir.glob(%w[exe/* lib/**/*.rb sig/**/*.rbs], base: __dir__) +
      %w[CHANGELOG.md LICENSE.txt README.md]
  spec.bindir = 'exe'
  spec.executables = ['carton']
  spec.require_paths = ['lib']
end
