# frozen_string_literal: true

require_relative 'shared_gems_prototype'
require_relative '../../lib/carton'
require 'json'
require 'open3'
require 'tmpdir'
require 'rbconfig'

def now = Process.clock_gettime(Process::CLOCK_MONOTONIC)

def rss_kb
  IO.popen(['/bin/ps', '-o', 'rss=', '-p', Process.pid.to_s], &:read).to_i
end

def loaded_features(box)
  box.eval("load #{File.expand_path('fixtures/observe.rb', __dir__).inspect}")
  box.instance_variable_get(:@spike_features)
end

def setup_bundle(box, gemfile)
  saved = ENV.to_h
  begin
    ENV['BUNDLE_GEMFILE'] = gemfile
    ENV.delete('BUNDLE_LOCKFILE')
    box.require(File.expand_path('bundle_setup.rb', __dir__))
  ensure
    ENV.replace(saved)
  end
end

if ARGV.first == '--worker'
  _, mode, count, workload = ARGV
  count = Integer(count)
  synthetic = workload == 'synthetic'
  gemfile = File.expand_path('Gemfile', __dir__)
  dependencies =
    (
      if synthetic
        [File.expand_path('fixtures/synthetic.rb', __dir__)]
      else
        %w[active_support active_support/core_ext]
      end
    )
  check = synthetic ? '"".shared_synthetic' : '["a", "b", "c"].to_sentence'
  expected = synthetic ? 'shared' : 'a, b, and c'
  boxes = []
  installments = []
  creation = []
  compiled = []
  trace =
    TracePoint.new(:script_compiled) do |event|
      compiled << event.instruction_sequence.path
    end
  GC.start
  baseline = rss_kb
  started = now
  trace.enable
  init_started = now
  shared = nil
  gem_features = []
  case mode
  when 'shared'
    shared =
      SharedGemsPrototype.new(
        gemfile: synthetic ? nil : gemfile,
        extra_builtins: %w[Enumerable Range Float Regexp],
      )
    before = loaded_features(shared.box)
    shared.load(*dependencies)
    gem_features.concat(loaded_features(shared.box) - before)
  when 'master'
    # Unsupported control only. This child process exits after this row.
    setup_bundle(Ruby::Box.main, gemfile) unless synthetic
    unless synthetic
      Ruby::Box.master.load_path.unshift(
        *Gem.loaded_specs.values.flat_map(&:full_require_paths),
      )
    end
    before = loaded_features(Ruby::Box.master)
    dependencies.each { |feature| Ruby::Box.master.require(feature) }
    gem_features.concat(loaded_features(Ruby::Box.master) - before)
  end
  initialization = now - init_started
  Dir.mktmpdir('shared-gems-bench') do |dir|
    count.times do |i|
      t = now
      if mode == 'carton'
        path = File.join(dir, "domain_#{i}.rb")
        code =
          synthetic ? '' : "Carton.setup_bundle(gemfile: #{gemfile.inspect})\n"
        code += dependencies.map { |f| "require #{f.inspect}" }.join("\n")
        lazy_code =
          synthetic ? 'nil' : 'ActiveSupport::Inflector.transliterate("café")'
        code +=
          "\nexport value: (#{check}), features: $LOADED_FEATURES.dup, " \
            "lazy: -> { #{lazy_code} }\n"
        File.write(path, code)
        result = import(path)
        equal(expected, result[:value])
        gem_features.concat(result[:features])
        boxes << result[:lazy]
        installments << (now - t)
      else
        box = Ruby::Box.new
        creation << (now - t)
        t = now
        before = loaded_features(box)
        if mode == 'independent'
          setup_bundle(box, gemfile) unless synthetic
          dependencies.each { |f| box.require(f) }
        elsif mode == 'shared'
          shared.install(box)
        end
        installments << (now - t)
        gem_features.concat(loaded_features(box) - before)
        boxes << box
        equal(expected, box.eval(check))
      end
    end
    boot = now - started
    lazy_started = now
    unless synthetic
      value =
        (
          if mode == 'carton'
            boxes.last.call
          else
            boxes.last.eval('ActiveSupport::Inflector.transliterate("café")')
          end
        )
      equal('cafe', value)
    end
    lazy = now - lazy_started
    trace.disable
    GC.start
    final_rss = rss_kb
    files =
      compiled.select do |p|
        p.end_with?('.rb') && !p.end_with?('/fixtures/observe.rb')
      end
    puts JSON.generate(
           mode: mode,
           boxes: count,
           workload: workload,
           initialization_s: initialization,
           box_creation_s: creation.sum,
           installation_s: installments.sum,
           installation_per_box_ms: installments.sum * 1000 / count,
           boot_s: boot,
           rss_baseline_kb: baseline,
           rss_final_kb: final_rss,
           rss_delta_kb: final_rss - baseline,
           rss_delta_per_box_kb: (final_rss - baseline).fdiv(count),
           ruby_files_compiled: files.size,
           dependency_files_compiled:
             files.count do |p|
               if synthetic
                 p.end_with?('/fixtures/synthetic.rb')
               else
                 p.include?('/active_support/') ||
                   p.end_with?('/active_support.rb')
               end
             end,
           gem_feature_loads: gem_features.count { |p| p.include?('/gems/') },
           installed_methods:
             shared ? shared.manifest.sum { |e| e[:methods].size } * count : 0,
           lazy_s: lazy,
           ruby: RUBY_DESCRIPTION,
         )
  end
else
  rows = []
  workloads = ARGV.include?('--synthetic') ? ['synthetic'] : ['active_support']
  workloads.each do |workload|
    %w[independent shared master carton].each do |mode|
      [1, 5, 10, 25, 50].each do |count|
        output, error, status =
          Open3.capture3(
            { 'RUBY_BOX' => '1' },
            RbConfig.ruby,
            __FILE__,
            '--worker',
            mode,
            count.to_s,
            workload,
          )
        abort "#{mode}/#{count}: #{error}" unless status.success?
        row = JSON.parse(output)
        rows << row
        warn "#{workload} #{mode} #{count}: #{row.fetch('boot_s').round(3)}s, #{row.fetch('rss_final_kb')} KB"
      end
    end
  end
  puts JSON.pretty_generate(rows)
end
