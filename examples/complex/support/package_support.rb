# frozen_string_literal: true

module ComplexExample
  module PackageSupport
    GEMFILE_NAMES = %w[gems.rb Gemfile].freeze

    module_function

    def add_package_libs(packages_dir)
      Dir
        .glob(File.join(packages_dir, '*', 'lib'))
        .sort
        .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }
    end

    def add_sibling_package_libs(entry_dir)
      package_root = File.expand_path('..', entry_dir)
      add_package_libs(File.expand_path('..', package_root))
    end

    def import_with_bundle(path)
      gemfile = gemfile_for_package_entry(path)
      return import(path) unless gemfile

      previous = ENV['BUNDLE_GEMFILE']
      ENV['BUNDLE_GEMFILE'] = gemfile
      import(path)
    ensure
      if previous
        ENV['BUNDLE_GEMFILE'] = previous
      else
        ENV.delete('BUNDLE_GEMFILE')
      end
    end

    def load_dotenv_payload(package_root:, env_file:)
      require 'json'
      require 'open3'
      require 'rbconfig'

      gemfile = gemfile_for(package_root)
      unless gemfile
        raise ArgumentError, "No Gemfile or gems.rb found in #{package_root}"
      end

      # Conflicting package bundles still need a subprocess today.
      script = <<~'RUBY'
        require 'json'
        require 'bundler/setup'
        require 'dotenv'

        config = Dotenv.parse(ARGV.fetch(0))
        version = Gem.loaded_specs.fetch('dotenv').version.to_s
        puts JSON.generate(version:, config:)
      RUBY

      output, status =
        Open3.capture2e(
          { 'BUNDLE_GEMFILE' => gemfile },
          RbConfig.ruby,
          '-e',
          script,
          env_file,
        )

      unless status.success?
        raise RuntimeError,
              "failed to load dotenv bundle from #{package_root}: #{output}"
      end

      JSON.parse(output)
    end

    def gemfile_for(dir)
      GEMFILE_NAMES.each do |name|
        path = File.expand_path(name, dir)
        return path if File.file?(path)
      end

      nil
    end

    def gemfile_for_package_entry(path)
      gemfile_for(File.expand_path('..', File.dirname(path)))
    end
  end
end
