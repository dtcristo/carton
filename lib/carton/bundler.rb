# frozen_string_literal: true

module Carton
  # Raised when Carton cannot find the bundle file for `setup_bundle`.
  class GemfileNotFound < StandardError
  end

  class << self
    # Set up the current carton's bundle, like `Bundler.setup(*groups)`.
    #
    # Bundler finds its Gemfile through process-global `ENV["BUNDLE_GEMFILE"]`
    # or the real process cwd. Carton resolves the Gemfile from the calling
    # file (or `gemfile:`, relative to it), points Bundler at it, and clears any
    # stale `BUNDLE_LOCKFILE` so Bundler derives the matching lockfile. All of
    # `ENV` is restored afterwards; Bundler keeps the selected Gemfile.
    def setup_bundle(*groups, gemfile: nil)
      path = resolve_bundle_gemfile(gemfile, caller_locations(1, 1).first)

      with_bundle_env(path) do
        require 'bundler'
        Bundler.ui.silence { Bundler.setup(*groups) }
      end
    end

    private

    # `ENV` is process-global. Bundler reads the Gemfile from it and exports
    # subprocess variables such as `RUBYOPT` into it, so restore all of it.
    def with_bundle_env(gemfile)
      previous_env = ENV.to_h
      ENV['BUNDLE_GEMFILE'] = gemfile
      ENV.delete 'BUNDLE_LOCKFILE'
      yield
    ensure
      ENV.replace(previous_env)
    end

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
