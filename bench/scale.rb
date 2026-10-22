# frozen_string_literal: true

# How import time and memory grow with the number of Cartons and the size of
# the bundle. Each measurement runs in a fresh Ruby process, since imports are
# cached for the life of the process.
#
#   ruby bench/scale.rb           # full run, Markdown tables on stdout
#   ruby bench/scale.rb --quick   # tiny sizes, one run each (used by tests)
#
# Run it outside any bundle; it sets RUBY_BOX=1 for its child processes.

require 'bundler'
require 'fileutils'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

module Bench
  ROOT = File.expand_path('..', __dir__)
  QUICK = ARGV.include?('--quick')
  RUNS = QUICK ? 1 : 3
  CARTON_COUNTS = QUICK ? [1, 5] : [1, 10, 50, 200]
  BUNDLE_SIZES = QUICK ? [5] : [10, 50, 200]
  GEM_CARTONS = QUICK ? 2 : 10
  EXAMPLES = QUICK ? [] : %w[rails_in_cartons]

  # The child script's measurement: seconds spent in the block, and resident
  # memory before and after it, in KB.
  MEASURE = <<~'RUBY'
    def rss_kb = Integer(`ps -o rss= -p #{Process.pid}`)

    def measure
      before = rss_kb
      started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      yield
      seconds = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
      puts JSON.generate(seconds:, rss_before: before, rss_after: rss_kb)
    end
  RUBY

  module_function

  def run
    puts "# Carton scale benchmark\n\n"
    puts "Ruby #{RUBY_VERSION}, #{RUBY_PLATFORM}, median of #{RUNS} runs.\n\n"
    plain_cartons
    gem_cartons
    examples
  end

  # N one-file Cartons imported with import_relative, against requiring the
  # same files without Carton.
  def plain_cartons
    puts "## Plain Cartons\n\n"
    puts '| Cartons | require (ms) | import (ms) | per import (ms) | ' \
           'memory per Carton (MB) |'
    puts '| ---: | ---: | ---: | ---: | ---: |'
    CARTON_COUNTS.each do |count|
      Dir.mktmpdir('carton-bench') do |dir|
        write_plain_cartons(dir, count)
        required = median { child(dir, plain_script(count, carton: false)) }
        imported = median { child(dir, plain_script(count, carton: true)) }
        memory = (imported[:rss] - required[:rss]) / 1024.0 / count
        puts "| #{count} | #{ms(required[:seconds])} | " \
               "#{ms(imported[:seconds])} | " \
               "#{ms(imported[:seconds] / count)} | #{memory.round(2)} |"
      end
    end
    puts
  end

  # GEM_CARTONS gem Cartons imported by name under bundles of growing size.
  # Each import rebuilds every locked spec in the new Box, so its cost should
  # grow with the lockfile.
  def gem_cartons
    puts "## Gem Cartons\n\n"
    puts "#{GEM_CARTONS} path gems imported by name under `bundler/setup`, " \
           "in bundles of growing size.\n\n"
    puts '| Locked gems | import (ms) | per import (ms) | ' \
           'memory per Carton (MB) |'
    puts '| ---: | ---: | ---: | ---: |'
    BUNDLE_SIZES.each do |size|
      Dir.mktmpdir('carton-bench') do |dir|
        gemfile = write_bundle(dir, size)
        env = { 'BUNDLE_GEMFILE' => gemfile }
        result = median { child(dir, gem_script, env:) }
        memory = result[:rss] / 1024.0 / GEM_CARTONS
        puts "| #{size + 1} | #{ms(result[:seconds])} | " \
               "#{ms(result[:seconds] / GEM_CARTONS)} | #{memory.round(2)} |"
      end
    end
    puts
  end

  # Whole-process wall time of the Rails Engine example, with its bundle installed.
  def examples
    return if EXAMPLES.empty?

    puts "## Rails example\n\n"
    puts '| Example | process wall time (ms) |'
    puts '| --- | ---: |'
    EXAMPLES.each do |name|
      dir = File.join(ROOT, 'examples', name)
      unless bundle_installed?(dir)
        puts "| #{name} | skipped: run `bundle exec rake example:#{name}` first |"
        next
      end

      seconds = median_seconds { wall_time(File.join(dir, 'main.rb')) }
      puts "| #{name} | #{ms(seconds)} |"
    end
    puts
  end

  def write_plain_cartons(dir, count)
    count.times do |i|
      File.write(
        File.join(dir, "c#{i}.rb"),
        "module C#{i}\n  def self.value = #{i}\nend\nexport C#{i}\n",
      )
      File.write(
        File.join(dir, "p#{i}.rb"),
        "module P#{i}\n  def self.value = #{i}\nend\n",
      )
    end
  end

  def plain_script(count, carton:)
    loads =
      if carton
        "#{count}.times { |i| import_relative(\"c\#{i}\") }"
      else
        "#{count}.times { |i| require_relative(\"p\#{i}\") }"
      end
    <<~RUBY
      require 'json'
      require #{File.join(ROOT, 'lib/carton').inspect}
      #{MEASURE}
      measure { #{loads} }
    RUBY
  end

  # `size` path gems plus carton, locked offline. Each gem is a one-file
  # Carton shaped like a real gem.
  def write_bundle(dir, size)
    gems =
      size.times.map do |i|
        lib = File.join(dir, 'gems', "g#{i}", 'lib')
        FileUtils.mkdir_p(lib)
        File.write(File.join(lib, "g#{i}.rb"), <<~RUBY)
          module G#{i}
            def self.value = #{i}
          end
          export G#{i}
        RUBY
        File.write(File.join(dir, 'gems', "g#{i}", "g#{i}.gemspec"), <<~RUBY)
          Gem::Specification.new do |s|
            s.name = 'g#{i}'
            s.version = '1.0.0'
            s.summary = 'bench'
            s.authors = ['bench']
            s.files = ['lib/g#{i}.rb']
          end
        RUBY
        "gem 'g#{i}', path: 'gems/g#{i}'"
      end
    gemfile = File.join(dir, 'Gemfile')
    File.write(
      gemfile,
      [%(gem 'carton', path: #{ROOT.inspect}), *gems].join("\n"),
    )
    bundle_lock(gemfile)
    gemfile
  end

  def gem_script
    <<~RUBY
      require 'json'
      require 'bundler/setup'
      require 'carton'
      #{MEASURE}
      measure { #{GEM_CARTONS}.times { |i| import("g\#{i}") } }
    RUBY
  end

  def bundle_lock(gemfile)
    _, error, status =
      Open3.capture3(
        clean_env.merge('BUNDLE_GEMFILE' => gemfile),
        'bundle',
        'lock',
        '--local',
      )
    raise "bundle lock failed: #{error}" unless status.success?
  end

  def bundle_installed?(dir)
    _, status =
      Open3.capture2e(
        clean_env.merge('BUNDLE_GEMFILE' => File.join(dir, 'Gemfile')),
        'bundle',
        'check',
        chdir: dir,
      )
    status.success?
  end

  # Runs `script` in a fresh process and returns its measurement, with the
  # memory it added.
  def child(dir, script, env: {})
    output, error, status =
      Open3.capture3(
        clean_env.merge(env).merge('RUBY_BOX' => '1'),
        RbConfig.ruby,
        '-e',
        script,
        chdir: dir,
      )
    raise "benchmark child failed:\n#{error}" unless status.success?

    result = JSON.parse(output.lines.last, symbolize_names: true)
    { seconds: result[:seconds], rss: result[:rss_after] - result[:rss_before] }
  end

  def wall_time(main)
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    _, status =
      Open3.capture2e(clean_env.merge('RUBY_BOX' => '1'), RbConfig.ruby, main)
    raise "#{main} failed" unless status.success?

    Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
  end

  # Children run outside whatever bundle started this script.
  def clean_env
    ENV.keys.grep(/\A(BUNDLER?_|RUBY(OPT|LIB)\z)/).to_h { |key| [key, nil] }
  end

  def median(&)
    results = Array.new(RUNS, &).sort_by { |result| result[:seconds] }
    results[results.size / 2]
  end

  def median_seconds(&) = Array.new(RUNS, &).sort[RUNS / 2]

  def ms(seconds) = (seconds * 1000).round(1)
end

Bundler.with_unbundled_env { Bench.run } if $PROGRAM_NAME == __FILE__
