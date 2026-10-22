# frozen_string_literal: true

require 'shellwords'
require 'rubocop/rake_task'

STREE_FILES =
  '"**/*.{rb,rake,gemspec}" "**/Rakefile" "**/Gemfile" "**/Steepfile" ' \
    'carton-tools/exe/carton "examples/**/bin/rails" "examples/**/config.ru" "examples/**/bin/hanami"'
RUBOCOP_FILES = %w[
  Gemfile
  Rakefile
  *.gemspec
  lib/**/*.rb
  test/*.rb
  test/carton/**/*.rb
  carton-tools/*.gemspec
  carton-tools/exe/carton
  carton-tools/lib/**/*.rb
  carton-tools/test/*.rb
  bench/*.rb
  examples/**/*.rb
  examples/**/*.gemspec
  examples/**/Gemfile
  examples/**/Rakefile
  examples/**/bin/rails
  examples/**/bin/hanami
  examples/**/config.ru
  spikes/master_prelude/**/*.rb
  spikes/master_prelude/Gemfile
  spikes/rails_reloading/**/*.rb
].freeze
EXAMPLES = %w[
  minimal
  tooling
  exports
  dependency_injection
  plugins
  bundler
  monorepo
  zeitwerk
  rails
  hanami
].freeze
TEST_BIGDECIMAL_VERSIONS = %w[4.1.1 3.3.1].freeze

def install_bundle(gemfile)
  dir = Shellwords.escape(File.dirname(gemfile))
  bundle_install_command = [
    '(BUNDLE_GEMFILE=Gemfile bundle check >/dev/null 2>&1 ||',
    'BUNDLE_FROZEN=1 BUNDLE_GEMFILE=Gemfile bundle install --quiet)',
  ].join(' ')
  command = ["cd #{dir}", bundle_install_command].join(' && ')

  sh(command, verbose: false)
end

def install_test_bigdecimals
  TEST_BIGDECIMAL_VERSIONS.each do |version|
    command =
      'gem list -i bigdecimal ' \
        "-v #{Shellwords.escape(version)} >/dev/null 2>&1 || " \
        "gem install bigdecimal -v #{Shellwords.escape(version)} " \
        '--no-document >/dev/null'
    sh(command, verbose: false)
  end
end

def test_runner
  <<~RUBY
    $stdout.sync = true
    $stderr.sync = true

    at_exit do
      status =
        if $!.is_a?(SystemExit)
          $!.status
        elsif $!
          1
        else
          0
        end

      Process.exit!(status)
    end

    ARGV.each { |file| require file }
  RUBY
end

desc 'Run all tests'
task :test do
  test_files =
    Dir
      .glob(%w[test/**/*_test.rb carton-tools/test/*_test.rb])
      .map { |f| File.expand_path(f) }
  command = [
    'RUBY_BOX=1 ruby -Ilib -Icarton-tools/lib -Itest ' \
      "-e #{Shellwords.escape(test_runner)}",
    *test_files.map { |file| Shellwords.escape(file) },
  ].join(' ')

  # Run outside the dev bundle so tests exercise plain RubyGems and their own
  # bundles. Install the Bundler-example deps the integration suite exercises.
  Bundler.with_unbundled_env do
    install_test_bigdecimals
    Dir
      .glob(File.join('examples', '{bundler,monorepo,plugins}', '**/Gemfile'))
      .each { |gemfile| install_bundle(gemfile) }
    sh(command, verbose: false)
  end
end

namespace :example do
  EXAMPLES.each do |name|
    desc "Run the #{name} example"
    task name.to_sym do
      dir = File.join('examples', name)

      puts
      puts "== Running example/#{name} =="
      puts

      Bundler.with_unbundled_env do
        Dir
          .glob(File.join(dir, '**/Gemfile'))
          .each { |gemfile| install_bundle(gemfile) }

        sh "RUBY_BOX=1 ruby #{Shellwords.escape(File.join(dir, 'main.rb'))}",
           verbose: false

        # One process per test file: a unit test's plain `require` must not
        # share the Main Box with another file's imports.
        Dir
          .glob(File.join(dir, 'test/**/*_test.rb'))
          .each do |file|
            sh "RUBY_BOX=1 ruby #{Shellwords.escape(file)}", verbose: false
          end
      end
    end
  end
end

task 'example:tooling' do
  Dir.chdir('examples/tooling') do
    sh 'bundle exec carton check main.rb', verbose: false
    sh 'bundle exec carton rbs main.rb', verbose: false
    sh 'bundle exec steep check', verbose: false
  end
end

# Spikes use explicit runners: the reload experiment borrows the ordinary
# Rails example as a fixture, while the Master prelude has its own bundle.
namespace :spike do
  desc 'Run the unsupported Master prelude experiment'
  task :master_prelude do
    Bundler.with_unbundled_env do
      install_bundle('spikes/master_prelude/Gemfile')
      sh 'RUBY_BOX=1 ruby spikes/master_prelude/main.rb', verbose: false
    end
  end

  desc 'Run the private Rails reloading experiment against a scratch app'
  task :rails_reloading do
    Bundler.with_unbundled_env do
      install_bundle('examples/rails/Gemfile')
      sh 'RUBY_BOX=1 ruby spikes/rails_reloading/test/reloading_test.rb',
         verbose: false
    end
  end
end

desc 'Run the CI-covered regression spikes'
task spikes: %i[spike:master_prelude spike:rails_reloading]

desc 'Measure import time and memory at scale'
task :bench do
  Bundler.with_unbundled_env { sh 'ruby bench/scale.rb', verbose: false }
end

desc 'Run all examples'
task examples: EXAMPLES.map { |n| "example:#{n}" }

desc 'Format code'
task :format do
  sh "bundle exec stree write #{STREE_FILES}", verbose: false
end

RuboCop::RakeTask.new do |task|
  task.patterns = RUBOCOP_FILES
  task.options = ['--force-exclusion']
end

task default: %i[test rubocop examples]
