# frozen_string_literal: true

require 'fileutils'
require 'optparse'
require_relative 'checks'
require_relative 'signatures'

module Carton
  module Tools
    # `carton rbs` and `carton check`. Both read code with Prism and never run
    # it, so neither needs `RUBY_BOX=1`.
    class CLI
      USAGE = <<~TEXT
        Usage: carton COMMAND [options] PATH...

        Commands:
          rbs    Write RBS for what each import returns
          check  Report import and export problems without running code

        PATH is a Ruby file or a directory of them, such as main.rb or app.
        Imports are followed into every Carton they reach.
      TEXT

      RBS_OUTPUT = 'sig/generated/carton.rbs'

      def self.start(argv, out: $stdout, err: $stderr)
        new(out:, err:).run(argv)
      end

      def initialize(out:, err:)
        @out = out
        @err = err
      end

      # Returns the exit status: 0 on success, 1 when `check` finds errors,
      # and 2 for a usage error.
      def run(argv)
        command, *args = argv
        case command
        when 'rbs'
          rbs(args)
        when 'check'
          check(args)
        when '-h', '--help'
          @out.puts USAGE
          0
        else
          @err.puts "carton: unknown command #{command}\n\n" if command
          @err.puts USAGE
          2
        end
      rescue OptionParser::ParseError, Errno::ENOENT => e
        @err.puts "carton: #{e.message}"
        2
      end

      private

      def rbs(args)
        output = RBS_OUTPUT
        project =
          project(args, 'rbs') do |o|
            o.on(
              '-o',
              '--output FILE',
              "Where to write the RBS (default #{RBS_OUTPUT}, - for stdout)",
            ) { |file| output = file }
          end
        return 2 unless project

        rbs = Signatures.new(project).to_s
        if output == '-'
          @out.print rbs
        else
          FileUtils.mkdir_p(File.dirname(output))
          File.write(output, rbs)
          @out.puts "Wrote #{output}"
        end
        0
      end

      def check(args)
        strict = false
        project =
          project(args, 'check') do |o|
            o.on('--strict', 'Fail on warnings too, not only errors') do
              strict = true
            end
          end
        return 2 unless project

        problems = Checks.new(project).problems
        pwd = File.realpath(Dir.pwd)
        problems.each do |problem|
          file = Project.relative(problem.file)
          message = problem.message.gsub("#{pwd}/", '').gsub(pwd, '.')
          @out.puts "#{file}:#{problem.line}: #{problem.level}: #{message}"
        end
        errors = problems.count(&:error?)
        @out.puts "#{project.files.size} files, #{project.units.size} Cartons, " \
                    "#{errors} errors, #{problems.size - errors} warnings"
        failures = strict ? problems.size : errors
        failures.zero? ? 0 : 1
      end

      # Parse options shared by every command, then scan PATHs. Named imports
      # resolve against `-I` directories, then this process's `$LOAD_PATH`,
      # which includes the bundle's gems under `bundle exec`, and files belong
      # to the gems RubyGems knows: the bundle's, or every installed gem.
      def project(args, command)
        includes = []
        parser =
          OptionParser.new do |o|
            o.banner = "Usage: carton #{command} [options] PATH..."
            o.on(
              '-I',
              '--include DIR',
              'Add DIR to the load path for named imports',
            ) { |dir| includes << File.expand_path(dir) }
            yield o if block_given?
          end
        paths = parser.parse(args)
        if paths.empty?
          @err.puts parser
          return
        end

        Project.new(paths, load_path: includes + $LOAD_PATH)
      end
    end

    private_constant :Checks, :Project, :Signatures, :SourceFile
  end
end
