# frozen_string_literal: true

module Carton
  # Maps an Import path to the file that should load, without evaluating any
  # code or reading Box state. The runtime passes the caller Box's
  # `$LOAD_PATH`; a static analyzer can pass any load path it has computed.
  module Resolver
    # `feature` is what the new Box requires. `load_path` is the single caller
    # load-path entry that matched a name-based Import, if any. The runtime
    # fills `gems` with the caller specs to activate in the new Box, and
    # `locked_gems` with the caller's locked specs when it ran Bundler setup.
    Target =
      Struct.new(:feature, :load_path, :gems, :locked_gems, keyword_init: true)

    EXTENSIONS = ['.rb', ".#{RbConfig::CONFIG['DLEXT']}"].freeze
    private_constant :EXTENSIONS

    module_function

    # Resolve `path` like `require_relative` when `base_dir` is given, like
    # `require` with an absolute path, or by searching `load_path` in order.
    # Only Ruby source files resolve to an absolute feature; anything else,
    # such as a native extension, comes back as the bare `path`.
    def resolve(path, load_path:, base_dir: nil)
      path = path.to_s
      if base_dir || File.absolute_path?(path)
        resolve_file(File.expand_path(path, base_dir))
      else
        resolve_name(path, load_path)
      end || Target.new(feature: path)
    end

    def resolve_file(expanded)
      [expanded, "#{expanded}.rb"].each do |candidate|
        return Target.new(feature: candidate) if File.file?(candidate)
      end
      nil
    end
    private_class_method :resolve_file

    # Like Ruby, check each load-path entry in order and try each extension
    # within it, so an earlier native extension shadows a later `.rb`.
    def resolve_name(path, load_path)
      candidates = feature_candidates(path)

      load_path.each do |entry|
        dir = File.expand_path(entry.to_s)
        candidates.each do |candidate|
          file = File.join(dir, candidate)
          next unless File.file?(file)
          return nil unless file.end_with?('.rb')

          return Target.new(feature: file, load_path: dir)
        end
      end
      nil
    end
    private_class_method :resolve_name

    def feature_candidates(path)
      return [path] if EXTENSIONS.include?(File.extname(path))

      EXTENSIONS.map { |ext| "#{path}#{ext}" }
    end
    private_class_method :feature_candidates
  end
end
