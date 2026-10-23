# frozen_string_literal: true

require_relative 'lib/carton/tools/version'

Gem::Specification.new do |spec|
  spec.name = 'carton-tools'
  spec.version = Carton::Tools::VERSION
  spec.authors = ['David Cristofaro']
  spec.email = ['david@dtcristo.com']

  spec.summary = 'Static checks and RBS for Carton'
  spec.description =
    'Carton enforces boundaries while code runs. The carton command finds ' \
      'problems before it does: carton check reports import and export ' \
      'problems and carton rbs writes RBS for what each import returns, ' \
      'reading code with Prism without running it. Requires Ruby 4.0.7+.'
  spec.homepage = 'https://carton.dtcristo.com'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0.7'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata[
    'source_code_uri'
  ] = 'https://github.com/dtcristo/carton/tree/main/carton-tools'
  spec.metadata[
    'changelog_uri'
  ] = 'https://github.com/dtcristo/carton/blob/main/CHANGELOG.md'

  # An explicit list, so packaging does not depend on git.
  spec.files =
    Dir.glob(%w[exe/* lib/**/*.rb], base: __dir__) + %w[LICENSE.txt README.md]
  spec.bindir = 'exe'
  spec.executables = ['carton']
  spec.require_paths = ['lib']

  # carton-tools reads Carton's resolver, errors, and export rules, so each
  # release pairs with exactly its own version of carton.
  spec.add_dependency 'carton', Carton::Tools::VERSION
  spec.add_dependency 'prism', '>= 1.8'
end
