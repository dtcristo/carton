# frozen_string_literal: true

module Carton
  # Maps an Import path to the file that should load, without evaluating any
  # code or reading Box state. The runtime passes the Importer's
  # `$LOAD_PATH`; a static analyzer can pass any load path it has computed.
  module Resolver
    # `feature` is what the new Box requires. `load_path` is the single Importer
    # load-path entry that matched a name-based Import, if any. The runtime
    # fills `gems` with the Gem Closure to activate in the new Box, and
    # `locked_gems` with the Importer's locked specs when it ran Bundler setup.
    # After loading, the Carton Box sets `gem_usage`, a callable returning the
    # gems the Carton depends on at that moment: its Gem Closure plus every
    # locked gem whose files it has loaded so far.
    Target =
      Struct.new(
        :feature,
        :load_path,
        :gems,
        :locked_gems,
        :gem_usage,
        keyword_init: true,
      )

    EXTENSIONS = ['.rb', ".#{RbConfig::CONFIG['DLEXT']}"].freeze
    private_constant :EXTENSIONS

    module_function

    # Resolve `path` like `require_relative` when `base_dir` is given, like
    # `require` with an absolute path, or by searching `load_path` in order.
    # A missing relative or absolute target raises LoadError, as
    # `require_relative` does. A name that matches no Ruby source file, such
    # as a native extension, comes back as the bare `path`. A file inside a
    # Carton raises ImportError: only its Entrypoint can be imported.
    def resolve(path, load_path:, base_dir: nil)
      target = locate(path, load_path:, base_dir:)
      reject_inside_carton(path.to_s, target)
      target
    end

    # Like `resolve`, but a file inside a Carton comes back as is, as
    # `require` would load it. `carton check` uses this for `require` calls.
    def locate(path, load_path:, base_dir: nil)
      path = path.to_s
      if base_dir || File.absolute_path?(path)
        resolve_file(File.expand_path(path, base_dir))
      else
        resolve_name(path, load_path) || Target.new(feature: path)
      end
    end

    # A Carton is its Entrypoint `x.rb` plus the `x/` directory beside it,
    # the shape of a gem's `lib/` and of a Zeitwerk explicit namespace.
    # Directories without their own `.rb` file, like Zeitwerk implicit
    # namespaces, stay inside the Carton above them. Returns the outermost
    # Entrypoint whose directory holds `file`, or `file` itself.
    def entrypoint_for(file)
      entrypoint = file
      dir = File.dirname(file)
      until dir == File.dirname(dir)
        entrypoint = "#{dir}.rb" if File.file?("#{dir}.rb")
        dir = File.dirname(dir)
      end
      entrypoint
    end

    def reject_inside_carton(path, target)
      return unless File.absolute_path?(target.feature)

      entrypoint = entrypoint_for(target.feature)
      return if entrypoint == target.feature

      raise ImportError, inside_carton_message(path, target, entrypoint)
    end
    private_class_method :reject_inside_carton

    def inside_carton_message(path, target, entrypoint)
      prefix = "#{target.load_path}/"
      fix =
        if target.load_path && entrypoint.start_with?(prefix)
          name = entrypoint.delete_prefix(prefix).delete_suffix('.rb')
          "#{path} is inside the #{name} Carton: import '#{name}'"
        else
          "#{target.feature} is inside the Carton #{entrypoint}: " \
            'import that file'
        end
      "#{fix}, or require it from inside that Carton"
    end
    private_class_method :inside_carton_message

    # A directory laid out like a gem, `billing/lib/billing.rb`, resolves to
    # that Entrypoint with its `lib/` on the Carton's load path, so the
    # Carton can `require 'billing/invoice'` as a gem would.
    def resolve_file(expanded)
      [expanded, "#{expanded}.rb"].each do |candidate|
        return Target.new(feature: candidate) if File.file?(candidate)
      end
      lib = File.join(expanded, 'lib')
      entrypoint = File.join(lib, "#{File.basename(expanded)}.rb")
      if File.file?(entrypoint)
        return Target.new(feature: entrypoint, load_path: lib)
      end

      raise LoadError, missing_file_message(expanded)
    end
    private_class_method :resolve_file

    # Name the files tried, relative to the directory they were tried in.
    def missing_file_message(expanded)
      name = File.basename(expanded)
      tried =
        if EXTENSIONS.include?(File.extname(name))
          [name]
        else
          ["#{name}.rb", "#{name}/lib/#{name}.rb"]
        end
      "cannot load such file -- #{expanded} " \
        "(tried #{tried.join(' and ')} in #{File.dirname(expanded)})"
    end
    private_class_method :missing_file_message

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
