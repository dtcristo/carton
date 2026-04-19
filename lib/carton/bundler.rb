# frozen_string_literal: true

module Carton
  # Raised when Carton cannot find the bundle file for `with_bundle`.
  class GemfileNotFound < StandardError
  end

  class << self
    # Scope Bundler's process-global file discovery to the current carton.
    #
    # Bundler still looks for its Gemfile through `ENV["BUNDLE_GEMFILE"]` or the
    # real process cwd. Carton resolves the bundle path from the calling file,
    # sets `BUNDLE_GEMFILE`, and clears any stale `BUNDLE_LOCKFILE` so Bundler
    # can derive the matching lockfile itself.
    def with_bundle(gemfile = nil)
      raise ArgumentError, 'with_bundle requires a block' unless block_given?

      previous_gemfile = ENV['BUNDLE_GEMFILE']
      previous_lockfile = ENV['BUNDLE_LOCKFILE']
      ENV['BUNDLE_GEMFILE'] = resolve_bundle_gemfile(
        gemfile,
        caller_locations(1, 1).first,
      )
      ENV.delete 'BUNDLE_LOCKFILE'
      yield
    ensure
      if previous_gemfile
        ENV['BUNDLE_GEMFILE'] = previous_gemfile
      else
        ENV.delete 'BUNDLE_GEMFILE'
      end

      if previous_lockfile
        ENV['BUNDLE_LOCKFILE'] = previous_lockfile
      else
        ENV.delete 'BUNDLE_LOCKFILE'
      end
    end

    private

    def resolve_bundle_gemfile(gemfile, call_site)
      caller_dir = caller_directory(call_site)
      return resolve_explicit_bundle_gemfile(gemfile, caller_dir) if gemfile

      current = caller_dir

      loop do
        bundle_gemfile_names.each do |name|
          candidate = File.join(current, name)
          return candidate if File.file?(candidate)
        end

        parent = File.dirname(current)
        break if parent == current

        current = parent
      end

      raise GemfileNotFound, "Gemfile not found from #{caller_dir}"
    end

    def resolve_explicit_bundle_gemfile(gemfile, caller_dir)
      resolved = File.expand_path(gemfile, caller_dir)
      return resolved if File.file?(resolved)

      raise GemfileNotFound, "Gemfile not found: #{resolved}"
    end

    def caller_directory(call_site)
      path = call_site&.absolute_path || call_site&.path
      return Dir.pwd unless path && !path.start_with?('(')

      File.dirname(File.expand_path(path))
    end

    def bundle_gemfile_names
      %w[gems.rb Gemfile]
    end
  end
end
