# frozen_string_literal: true

require 'carton/error'
require 'carton/resolver'
require_relative 'source_file'

module Carton
  module Tools
    # The Cartons an app imports, found by following `import` and
    # `import_relative` calls from the given files without running them.
    # Name-based imports resolve against `load_path`, as they would against the
    # importing Box's `$LOAD_PATH`. `specs` are the gems that files may belong
    # to: under Bundler, the bundle's.
    class Project
      # A Carton: its Entrypoint, its files (the Entrypoint plus its namespace
      # directory), and the `lib/` a gem-shaped directory import adds to its
      # load path.
      Unit =
        Data.define(:entrypoint, :files, :load_path) do
          def name = File.basename(entrypoint, '.rb')
        end

      # One import call and what it resolved to: a Unit, an error message, or
      # a name not found on the load path, which a gem activated at runtime
      # may still provide.
      Edge = Data.define(:call, :unit, :error, :unfound)

      attr_reader :files, :units, :edges

      # `path` relative to the current directory, for messages and comments.
      def self.relative(path)
        pwd = File.realpath(Dir.pwd)
        path.start_with?("#{pwd}/") ? path.delete_prefix("#{pwd}/") : path
      end

      def initialize(paths, load_path: [], specs: nil)
        @load_path = load_path
        @specs = specs
        @files = {}
        @units = {}
        @unit_by_file = {}
        ruby_files(paths).each { |path| parse(path) }
        discover
        @edges = imports.map { |call| resolve(call) }
        @edge_by_call = @edges.to_h { |edge| [edge.call, edge] }
      end

      # The absolute path an import or require loads, or nil.
      def target(call)
        unless SourceFile::IMPORTS.include?(call.kind.to_sym)
          return locate(call)
        end

        @edge_by_call[call]&.unit&.entrypoint
      end

      # The gem whose require paths hold `path`, or nil.
      def gem_for(path)
        gem_dirs
          .select { |dir, _| path.start_with?("#{dir}/") }
          .max_by { |dir, _| dir.length }
          &.last
      end

      # The Unit `file` belongs to, or nil for the app, which runs in Main.
      def owner(file) = @unit_by_file[file]

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

      # The Unit whose files include `path`, if that Unit is imported.
      def unit_containing(path)
        @unit_by_file[path] || @units[Resolver.entrypoint_for(path)]
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

            Dir.glob('**/*.rb', base: path).sort.map { |f| File.join(path, f) }
          end
        files.map { |path| File.realpath(path) }
      end

      def parse(path) = @files[path] ||= SourceFile.parse(path)

      # Follow imports and `require_relative` calls until no new files or
      # Cartons turn up. A file's load path depends on the Carton it belongs
      # to, which may be found after the file is read.
      def discover
        loop do
          required =
            requires.select(&:relative?).filter_map { |call| locate(call) }
          required = required.grep(/\.rb\z/).reject { |path| @files.key?(path) }
          found = imports.filter_map { |call| resolve(call).unit }
          fresh = found.reject { |unit| @units.key?(unit.entrypoint) }
          break if required.empty? && fresh.empty?

          required.each { |path| parse(path) }
          fresh.each { |unit| add_unit(unit) }
        end
      end

      def add_unit(unit)
        @units[unit.entrypoint] = unit
        unit.files.each do |file|
          @unit_by_file[file] ||= unit
          parse(file)
        end
      end

      def resolve(call)
        unless call.path
          return Edge.new(call:, unit: nil, error: nil, unfound: false)
        end

        base_dir = File.dirname(call.file) if call.relative?
        target =
          Resolver.resolve(
            call.path,
            load_path: load_path_for(call.file),
            base_dir:,
          )
        unless File.absolute_path?(target.feature)
          return Edge.new(call:, unit: nil, error: nil, unfound: true)
        end

        Edge.new(call:, unit: unit_for(target), error: nil, unfound: false)
      rescue ImportError, LoadError => e
        Edge.new(call:, unit: nil, error: e.message, unfound: false)
      end

      def unit_for(target)
        entrypoint = File.realpath(target.feature)
        @units.fetch(entrypoint) do
          dir = entrypoint.delete_suffix('.rb')
          files =
            Dir
              .glob('**/*.rb', base: dir)
              .sort
              .map { |file| File.realpath(File.join(dir, file)) }
          Unit.new(
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
