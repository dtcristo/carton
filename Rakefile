# frozen_string_literal: true

require 'shellwords'

STREE_FILES = '"**/*.{rb,rake,gemspec}" "**/Rakefile" "**/Gemfile"'
EXAMPLES = %w[minimal gems bundler].freeze
GEMS_EXAMPLE_BIGDECIMAL_VERSIONS = %w[4.1.1 3.3.1].freeze

def install_example_bundle(gemfile)
  dir = Shellwords.escape(File.dirname(gemfile))

  sh(
    "cd #{dir} && " \
      '(BUNDLE_GEMFILE=Gemfile bundle check >/dev/null 2>&1 || ' \
      'BUNDLE_FROZEN=1 BUNDLE_GEMFILE=Gemfile bundle install --quiet)',
    verbose: false,
  )
end

def install_example_bigdecimals
  GEMS_EXAMPLE_BIGDECIMAL_VERSIONS.each do |version|
    sh(
      'gem list -i bigdecimal ' \
        "-v #{Shellwords.escape(version)} >/dev/null 2>&1 || " \
        "gem install bigdecimal -v #{Shellwords.escape(version)} " \
        '--no-document >/dev/null',
      verbose: false,
    )
  end
end

def test_runner
  <<~RUBY
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
    Dir.glob('test/**/*_test.rb').sort.map { |f| File.expand_path(f) }
  sh(
    "RUBY_BOX=1 ruby -Ilib -Itest -e #{Shellwords.escape(test_runner)} " \
      "#{test_files.map { |file| Shellwords.escape(file) }.join(' ')}",
    verbose: false,
  )
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
        install_example_bigdecimals if name == 'gems'

        Dir
          .glob(File.join(dir, '**/Gemfile'))
          .sort
          .each { |gemfile| install_example_bundle(gemfile) }

        sh "RUBY_BOX=1 ruby #{Shellwords.escape(File.join(dir, 'main.rb'))}",
           verbose: false
      end
    end
  end
end

desc 'Run all examples'
task examples: EXAMPLES.map { |n| "example:#{n}" }

desc 'Format code'
task :format do
  sh "bundle exec stree write #{STREE_FILES}", verbose: false
end

task default: %i[test examples]
