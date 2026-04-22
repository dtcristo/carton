# frozen_string_literal: true

module Carton
  # Raised when Carton cannot find the bundle file for `with_bundle`.
  class GemfileNotFound < StandardError
  end

  module BundlerSupport
    # RubyGems defines `full_require_paths` in the root box during boot. Under
    # `Ruby::Box`, Bundler path gems can then keep a synthetic install path there
    # even though `loaded_from` points at the real checkout. Recompute path-gem
    # load paths from the live gemspec location in the current box.
    module SpecificationLoadPaths
      def full_require_paths
        root = real_require_paths_root
        return super unless root

        paths = raw_require_paths.map { |path| File.join(root, path) }
        paths << extension_dir if have_extensions?
        paths
      end

      def load_paths
        full_require_paths
      end

      private

      def real_require_paths_root
        return unless raw_require_paths.any?
        return unless loaded_from && File.file?(loaded_from)

        root = File.dirname(loaded_from)
        if raw_require_paths.all? { |path|
             File.directory?(File.join(root, path))
           }
          return root
        end
      end
    end
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

      install_bundler_support!
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

    def install_bundler_support!
      return unless defined?(Ruby::Box) && Ruby::Box.enabled?
      if Gem::BasicSpecification.ancestors.include?(
           BundlerSupport::SpecificationLoadPaths,
         )
        return
      end

      Gem::BasicSpecification.prepend(BundlerSupport::SpecificationLoadPaths)
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
