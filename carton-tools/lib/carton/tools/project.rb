# frozen_string_literal: true

require 'pathname'
require 'carton/error'
require 'carton/resolver'
require_relative 'source_file'

module Carton
  module Tools
    # The Cartons an app imports, found by following `import` and
    # `import_relative` calls from the given files without running them.
    # Name-based imports resolve against `load_path`, as they would against the
    # Importer's `$LOAD_PATH`. `specs` are the gems that files may belong
    # to: under Bundler, the bundle's.
    class Project
      # A Carton: its Entrypoint, its files (the Entrypoint plus its Interior),
      # and the `lib/` an Import of a Gem-shaped Directory adds to its load
      # path.
      Carton = Data.define(:entrypoint, :files, :load_path)

      # One import call and what it resolved to: a Carton, an error message,
      # or a name not found on the load path, which a gem activated at runtime
      # may still provide.
      Edge = Data.define(:call, :carton, :error, :unfound)

      # Directory scans skip installed gems.
      DEFAULT_EXCLUDES = ['**/vendor/bundle'].freeze

      # A directory PATH with no Ruby files left to scan.
      class EmptyError < StandardError
      end

      attr_reader :files, :cartons, :edges

      # `exclude` lists globs, matched against each path inside a directory
      # PATH and its parent directories, that the scan skips.
      def initialize(paths, load_path: [], specs: nil, exclude: [])
        @pwd = File.realpath(Dir.pwd)
        # The working directory, where a path or a message's quote or
        # punctuation starts and a path separator or the end follows.
        @pwd_pattern =
          %r{(?<![^\s'"(:,=])#{Regexp.escape(@pwd)}(/|(?=\z|[\s'"):,]))}
        @load_path = load_path
        @specs = specs
        @files = {}
        @cartons = {}
        @carton_by_file = {}
        @edge_by_call = {}.compare_by_identity
        @exclude = DEFAULT_EXCLUDES + exclude
        discover(ruby_files(paths).map { |path| parse(path) })
        @edges = imports.map { |call| edge(call) }
      end

      # The absolute path an import or require loads, or nil.
      def target(call)
        return locate(call) unless SourceFile::IMPORTS.include?(call.kind)

        @edge_by_call[call]&.carton&.entrypoint
      end

      # `text`, a path or a message, with paths inside the current directory
      # made relative to it. Paths outside it stay absolute.
      def relative(text)
        text.gsub(@pwd_pattern) { Regexp.last_match(1) == '/' ? '' : '.' }
      end

      # A Carton's name in messages: its Entrypoint relative to the current
      # directory, such as `billing.rb` or `../shared/billing.rb`.
      def label(carton)
        Pathname(carton.entrypoint).relative_path_from(@pwd).to_s
      end

      # The gem whose require paths hold `path`, or nil.
      def gem_for(path)
        gem_dirs
          .select { |dir, _| path.start_with?("#{dir}/") }
          .max_by { |dir, _| dir.length }
          &.last
      end

      # The Carton `file` belongs to, or nil for the app, which runs in Main.
      def owner(file) = @carton_by_file[file]

      def imports = @files.values.flat_map(&:imports)

      def requires = @files.values.flat_map(&:requires)

      # Resolve a `require` or `require_relative` call as Ruby would, to an
      # absolute path or nil.
      def locate(call)
        return unless call.path

        base_dir = File.dirname(call.file) if call.relative?
        feature =
          Resolver.locate(
            call.path,
            load_path: load_path_for(call.file),
            base_dir:,
          ).feature
        File.realpath(feature) if File.absolute_path?(feature)
      rescue LoadError
        nil
      end

      # The Carton whose files include `path`, if that Carton is imported.
      def carton_containing(path)
        @carton_by_file[path] || @cartons[Resolver.entrypoint_for(path)]
      end

      private

      def gem_dirs
        @gem_dirs ||=
          (@specs || Gem::Specification.to_a).flat_map do |spec|
            spec.full_require_paths.filter_map do |dir|
              [File.realpath(dir), spec] if File.directory?(dir)
            end
          end
      end

      def ruby_files(paths)
        files =
          paths.flat_map do |path|
            next [path] unless File.directory?(path)

            found =
              Dir
                .glob('**/*.rb', base: path)
                .reject { |file| excluded?(file) }
                .sort
            raise EmptyError, "no Ruby files in #{path}" if found.empty?

            found.map { |file| File.join(path, file) }
          end
        files.map { |path| File.realpath(path) }
      end

      def excluded?(file)
        parts = file.split('/')
        prefixes = (1..parts.size).map { |size| parts.first(size).join('/') }
        @exclude.any? do |pattern|
          prefixes.any? do |prefix|
            File.fnmatch?(
              pattern,
              prefix,
              File::FNM_PATHNAME | File::FNM_EXTGLOB,
            )
          end
        end
      end

      def parse(path) = @files[path] ||= SourceFile.parse(path)

      # Follow imports and `require_relative` calls from each file in turn
      # until no new files or Cartons turn up.
      def discover(queue)
        until queue.empty?
          file = queue.shift
          file.requires.each do |call|
            next unless call.relative?

            path = locate(call)
            queue << parse(path) if path&.end_with?('.rb') && !@files.key?(path)
          end
          file.imports.each do |call|
            carton = edge(call).carton
            next if carton.nil? || @cartons.key?(carton.entrypoint)

            queue.concat(add_carton(carton))
          end
        end
      end

      # The Carton's files to read again: new ones, and ones read before
      # their Carton was found. A file's load path depends on its Carton, so
      # the latter's imports resolve again.
      def add_carton(carton)
        @cartons[carton.entrypoint] = carton
        carton.files.filter_map do |path|
          next if @carton_by_file.key?(path)

          @carton_by_file[path] = carton
          if @files.key?(path)
            @files[path].imports.each { |call| @edge_by_call.delete(call) }
          end
          parse(path)
        end
      end

      # Each import resolves once, unless its file's Carton changes.
      def edge(call) = @edge_by_call[call] ||= resolve(call)

      def resolve(call)
        unless call.path
          return Edge.new(call:, carton: nil, error: nil, unfound: false)
        end

        base_dir = File.dirname(call.file) if call.relative?
        target =
          Resolver.resolve(
            call.path,
            load_path: load_path_for(call.file),
            base_dir:,
          )
        unless File.absolute_path?(target.feature)
          return Edge.new(call:, carton: nil, error: nil, unfound: true)
        end

        Edge.new(call:, carton: carton_for(target), error: nil, unfound: false)
      rescue ImportError, LoadError => e
        Edge.new(call:, carton: nil, error: e.message, unfound: false)
      end

      def carton_for(target)
        entrypoint = File.realpath(target.feature)
        @cartons.fetch(entrypoint) do
          dir = entrypoint.delete_suffix('.rb')
          files =
            Dir
              .glob('**/*.rb', base: dir)
              .sort
              .map { |file| File.realpath(File.join(dir, file)) }
          Carton.new(
            entrypoint:,
            files: [entrypoint, *files],
            load_path: target.load_path,
          )
        end
      end

      # Like the runtime, a gem-shaped Carton's `lib/` comes first in its Box.
      def load_path_for(file)
        [owner(file)&.load_path, *@load_path].compact
      end
    end
  end
end
