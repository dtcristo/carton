# frozen_string_literal: true

require 'fileutils'
require 'shellwords'
require 'tmpdir'

STREE_FILES = '"**/*.{rb,rake,gemspec}" "**/Rakefile" "**/Gemfile"'
EXAMPLES = {
  'minimal' => 'minimal',
  'gems' => 'gems',
  'bundler' => 'bundler',
  'gem' => 'gem_in_carton',
}.freeze
NON_BUNDLER_BIGDECIMAL_VERSIONS = %w[4.1.1 3.3.1].freeze
PATCHED_BIGDECIMAL_VERSION = '2.0.3'
PATCHED_BIGDECIMAL_SOURCE =
  '#define ENTER(n) volatile VALUE RB_UNUSED_VAR(vStack[n]);int iStack=0'
PATCHED_BIGDECIMAL_REPLACEMENT =
  '#define ENTER(n) volatile VALUE vStack[n];int iStack=0'

def example_dir(name)
  File.join('examples', EXAMPLES.fetch(name))
end

def install_example_bundle(gemfile, env = {})
  dir = Shellwords.escape(File.dirname(gemfile))
  env_vars =
    env.map { |key, value| "#{key}=#{Shellwords.escape(value)}" }.join(' ')
  command =
    'BUNDLE_GEMFILE=Gemfile bundle check >/dev/null 2>&1 || ' \
      'BUNDLE_FROZEN=1 BUNDLE_GEMFILE=Gemfile bundle install --quiet'

  sh(
    "cd #{dir} && env #{env_vars} sh -c #{Shellwords.escape(command)}",
    verbose: false,
  )
end

def install_example_bigdecimals(dir)
  gem_home = File.expand_path('.gem-home', dir)
  escaped_home = Shellwords.escape(gem_home)

  FileUtils.mkdir_p(gem_home)

  NON_BUNDLER_BIGDECIMAL_VERSIONS.each do |version|
    command =
      "gem list -i bigdecimal -v #{Shellwords.escape(version)} " \
        '> /dev/null 2>&1 || ' \
        "gem install bigdecimal -v #{Shellwords.escape(version)} " \
        '--no-document > /dev/null'

    sh(
      "env GEM_HOME=#{escaped_home} GEM_PATH=#{escaped_home} sh -c " \
        "#{Shellwords.escape(command)}",
      verbose: false,
    )
  end

  gem_home
end

def prepare_patched_bigdecimal!
  vendor_dir =
    File.expand_path(
      "examples/.vendor/bigdecimal-#{PATCHED_BIGDECIMAL_VERSION}",
      __dir__,
    )
  gemspec = File.join(vendor_dir, 'bigdecimal.gemspec')
  return vendor_dir if File.file?(gemspec)

  FileUtils.mkdir_p(File.dirname(vendor_dir))

  Dir.mktmpdir('carton-bigdecimal') do |dir|
    Dir.chdir(dir) do
      sh "gem fetch bigdecimal -v #{PATCHED_BIGDECIMAL_VERSION}", verbose: false
      sh "gem unpack bigdecimal-#{PATCHED_BIGDECIMAL_VERSION}.gem",
         verbose: false
    end

    FileUtils.rm_rf(vendor_dir)
    FileUtils.mv(
      File.join(dir, "bigdecimal-#{PATCHED_BIGDECIMAL_VERSION}"),
      vendor_dir,
    )
  end

  source = File.join(vendor_dir, 'ext', 'bigdecimal', 'bigdecimal.c')
  contents = File.read(source)
  patched =
    contents.sub(PATCHED_BIGDECIMAL_SOURCE, PATCHED_BIGDECIMAL_REPLACEMENT)
  raise 'failed to patch bigdecimal 2.0.3 for Ruby 4.0.2' if patched == contents

  File.write(source, patched)
  vendor_dir
end

def install_shared_bigdecimal!
  vendor_dir = prepare_patched_bigdecimal!
  gem_home = File.expand_path('examples/.gem-home', __dir__)
  gemspec =
    File.join(
      gem_home,
      'specifications',
      "bigdecimal-#{PATCHED_BIGDECIMAL_VERSION}.gemspec",
    )
  return gem_home if File.file?(gemspec)

  FileUtils.mkdir_p(gem_home)

  gem_file =
    File.join(vendor_dir, "bigdecimal-#{PATCHED_BIGDECIMAL_VERSION}.gem")

  Dir.chdir(vendor_dir) do
    unless File.file?(gem_file)
      sh 'gem build bigdecimal.gemspec >/dev/null', verbose: false
    end
  end

  env_vars =
    "GEM_HOME=#{Shellwords.escape(gem_home)} " \
      "GEM_PATH=#{Shellwords.escape(gem_home)}"

  sh(
    "env #{env_vars} gem install #{Shellwords.escape(gem_file)} " \
      '--no-document >/dev/null',
    verbose: false,
  )

  gem_home
end

def example_env(name, dir)
  case name
  when 'gems'
    gem_home = install_example_bigdecimals(dir)
    { 'GEM_HOME' => gem_home, 'GEM_PATH' => gem_home }
  when 'bundler', 'gem'
    gem_home = install_shared_bigdecimal!
    { 'GEM_HOME' => gem_home, 'GEM_PATH' => gem_home }
  else
    {}
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
  EXAMPLES.each_key do |name|
    desc "Run the #{name} example"
    task name.to_sym do
      dir = example_dir(name)

      puts
      puts "== Running example/#{name} =="
      puts

      Bundler.with_unbundled_env do
        env = example_env(name, dir)

        Dir
          .glob(File.join(dir, '**/Gemfile'))
          .sort
          .each { |gemfile| install_example_bundle(gemfile, env) }

        command = [
          'env',
          *env.map { |key, value| "#{key}=#{Shellwords.escape(value)}" },
          'RUBY_BOX=1',
          'ruby',
          Shellwords.escape(File.join(dir, 'main.rb')),
        ].reject(&:empty?).join(' ')

        sh(command, verbose: false)
      end
    end
  end
end

desc 'Run all examples'
task examples: EXAMPLES.keys.map { |n| "example:#{n}" }

desc 'Format code'
task :format do
  sh "bundle exec stree write #{STREE_FILES}", verbose: false
end

task default: %i[test examples]
