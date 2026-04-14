# frozen_string_literal: true

STREE_FILES = '"**/*.{rb,rake,gemspec}" "**/Rakefile" "**/Gemfile"'
EXAMPLES = %w[minimal complex].freeze

desc 'Run all tests'
task :test do
  test_files =
    Dir.glob('test/**/*_test.rb').sort.map { |f| File.expand_path(f) }
  sh "RUBY_BOX=1 ruby -Ilib -Itest -e 'ARGV.each { |f| require f }' #{test_files.join(' ')}",
     verbose: false
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
        # Install gems for any package/local example gemfile.
        Dir
          .glob(File.join(dir, '**/Gemfile'))
          .each do |gemfile|
            pkg_dir = File.dirname(gemfile)
            sh(
              "cd #{pkg_dir} && " \
                'BUNDLE_GEMFILE=Gemfile bundle check >/dev/null 2>&1 || ' \
                'BUNDLE_GEMFILE=Gemfile bundle install --quiet',
              verbose: false,
            )
          end

        sh "RUBY_BOX=1 ruby #{File.join(dir, 'main.rb')}", verbose: false
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
