# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'optparse'
require_relative 'checks'
require_relative 'signatures'
require_relative 'version'

module Carton
  module Tools
    # `carton rbs` and `carton check`. Both read code with Prism and never run
    # it, so neither needs `RUBY_BOX=1`.
    class CLI
      COMMANDS = {
        'check' => 'Report import and export problems without running code',
        'rbs' => 'Write RBS for what each import returns',
      }.freeze

      USAGE = <<~TEXT
        Usage: carton COMMAND [options] PATH...

        Commands:
        #{COMMANDS.map { |name, summary| "  #{name.ljust(6)} #{summary}" }.join("\n")}

        Options:
          -h, --help     Show this help
          -v, --version  Show the version

        PATH is a Ruby file or a directory of them, such as main.rb or app.
        Imports are followed into every Carton they reach.
        Run carton help COMMAND for a command's options.
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
      # and 2 for a usage or file error. `--help` and `--version` print to
      # `out` and return 0.
      def run(argv)
        command, *args = argv
        catch(:exit) do
          case command
          when *COMMANDS.keys
            send(command, args)
          when 'help'
            help(args)
          when '-h', '--help'
            @out.puts USAGE
            0
          when '-v', '--version'
            @out.puts "carton #{VERSION}"
            0
          else
            @err.puts "carton: unknown command #{command}\n\n" if command
            @err.puts USAGE
            2
          end
        end
      rescue OptionParser::ParseError => e
        @err.puts "carton: #{e.message}"
        2
      rescue SystemCallError => e
        @err.puts "carton: #{system_message(e)}"
        2
      end

      private

      def help(args)
        return run([args.first, '--help']) if COMMANDS.key?(args.first)

        run(args.empty? ? ['--help'] : args)
      end

      # `PATH: strerror`, without Ruby's ` @ function` detail.
      def system_message(error)
        reason = SystemCallError.new(nil, error.errno).message
        path = error.message.delete_prefix(reason).sub(/\A(?: @ \S+)? - /, '')
        path.empty? || path == error.message ? reason : "#{path}: #{reason}"
      end

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
        format = 'text'
        project =
          project(args, 'check') do |o|
            o.on('--strict', 'Fail on warnings too, not only errors') do
              strict = true
            end
            o.on(
              '--format FORMAT',
              %w[text json],
              'text (default) or json',
            ) { |value| format = value }
          end
        return 2 unless project

        problems = Checks.new(project).problems
        errors = problems.count(&:error?)
        summary = {
          files: project.files.size,
          cartons: project.cartons.size,
          errors:,
          warnings: problems.size - errors,
        }
        if format == 'json'
          print_json(project, problems, summary)
        else
          print_text(project, problems, summary)
        end
        failures = strict ? problems.size : errors
        failures.zero? ? 0 : 1
      end

      def print_text(project, problems, summary)
        problems.each do |problem|
          @out.puts "#{project.relative(problem.file)}:#{problem.line}: " \
                      "#{problem.level}: #{project.relative(problem.message)}"
        end
        @out.puts "#{summary[:files]} files, #{summary[:cartons]} Cartons, " \
                    "#{summary[:errors]} errors, #{summary[:warnings]} warnings"
      end

      def print_json(project, problems, summary)
        list =
          problems.map do |problem|
            {
              level: problem.level,
              file: project.relative(problem.file),
              line: problem.line,
              message: project.relative(problem.message),
            }
          end
        @out.puts JSON.pretty_generate(problems: list, **summary)
      end

      # Parse options shared by every command, then scan PATHs. Named imports
      # resolve against `-I` directories, then this process's `$LOAD_PATH`,
      # which includes the bundle's gems under `bundle exec`, and files belong
      # to the gems RubyGems knows: the bundle's, or every installed gem.
      def project(args, command)
        includes = []
        parser =
          OptionParser.new do |o|
            o.program_name = 'carton'
            o.version = VERSION
            o.banner = "Usage: carton #{command} [options] PATH..."
            o.on(
              '-I',
              '--include DIR',
              'Add DIR to the load path for named imports',
            ) { |dir| includes << File.expand_path(dir) }
            yield o if block_given?
            o.on_tail('-h', '--help', 'Show this help') do
              @out.puts o
              throw :exit, 0
            end
            o.on_tail('-v', '--version', 'Show the version') do
              @out.puts "carton #{VERSION}"
              throw :exit, 0
            end
          end
        paths = parser.parse(args)
        if paths.empty?
          @err.puts parser
          return
        end

        Project.new(paths, load_path: includes + $LOAD_PATH)
      end
    end
  end
end
