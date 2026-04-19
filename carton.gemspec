# frozen_string_literal: true

require_relative 'lib/carton/version'

Gem::Specification.new do |spec|
  spec.name = 'carton'
  spec.version = Carton::VERSION
  spec.authors = ['David Cristofaro']
  spec.email = ['david@dtcristo.com']

  spec.summary = 'Thin import/export wrapper around Ruby::Box'
  spec.description =
    'Carton wraps Ruby::Box with small import/export helpers so Ruby files can expose explicit APIs while keeping constants, gems, and monkey patches boxed.'
  spec.homepage = 'https://github.com/dtcristo/carton'
  spec.license = 'MIT'
  spec.required_ruby_version = '>= 4.0.0'

  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata[
    'changelog_uri'
  ] = 'https://github.com/dtcristo/carton/blob/main/CHANGELOG.md'

  gemspec = File.basename(__FILE__)
  spec.files =
    IO.popen(%w[git ls-files -z], chdir: __dir__, err: IO::NULL) do |ls|
      ls
        .readlines("\x0", chomp: true)
        .reject do |f|
          (f == gemspec) ||
            f.start_with?(
              *%w[
                .github/
                bin/
                test/
                .gitignore
                .mise.toml
                .rubocop.yml
                .streerc
                Gemfile
              ],
            )
        end
    end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ['lib']
end
