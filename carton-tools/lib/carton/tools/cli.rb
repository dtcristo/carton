# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'optparse'
require_relative 'checks'
require_relative 'import_graph'
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
        'graph' => 'Print the import graph as Mermaid or DOT',
        'why' => 'Show the imports that lead from one file to a Carton',
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
      rescue OptionParser::ParseError, Project::EmptyError => e
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
        check = false
        project =
          project(args, 'rbs') do |o|
            o.on(
              '-o',
              '--output FILE',
              "Where to write the RBS (default #{RBS_OUTPUT}, - for stdout)",
            ) { |file| output = file }
            o.on(
              '--check',
              'Exit 1 if the output file is missing or stale; write nothing',
            ) { check = true }
          end
        return 2 unless project

        rbs = Signatures.new(project).to_s
        return rbs_check(output, rbs) if check

        if output == '-'
          @out.print rbs
        elsif File.file?(output) && File.read(output) == rbs
          @out.puts "#{output} is up to date"
        else
          FileUtils.mkdir_p(File.dirname(output))
          File.write(output, rbs)
          @out.puts "Wrote #{output}"
        end
        0
      end

      def rbs_check(output, rbs)
        if output == '-'
          @err.puts 'carton: --check compares with a file, so -o - is not allowed'
          return 2
        end
        unless File.exist?(output)
          @out.puts "#{output} is missing: run carton rbs to write it"
          return 1
        end

        current = File.read(output)
        if current == rbs
          @out.puts "#{output} is up to date"
          return 0
        end

        line = first_difference(current.lines, rbs.lines) + 1
        @out.puts "#{output} is stale from line #{line}: run carton rbs to update it"
        1
      end

      def first_difference(old, new)
        (0...[old.size, new.size].max).find { |index| old[index] != new[index] }
      end

      # Nodes are Cartons, named by Entrypoint, and Main for the app. A
      # dashed edge is lazy: every import behind it runs in a method or block.
      def graph(args)
        format = 'mermaid'
        project =
          project(args, 'graph') do |o|
            o.on(
              '--format FORMAT',
              %w[mermaid dot],
              'mermaid (default) or dot',
            ) { |value| format = value }
          end
        return 2 unless project

        graph = ImportGraph.new(project)
        ids =
          graph.nodes.each_with_index.to_h { |node, index| [node, "n#{index}"] }
        label = ->(node) do
          node ? project.label(project.cartons.fetch(node)) : 'Main'
        end
        target = ->(edge) { edge.carton.entrypoint }
        source = ->(edge) { project.owner(edge.call.file)&.entrypoint }
        if format == 'dot'
          @out.puts 'digraph cartons {'
          ids.each do |node, id|
            shape = node ? '' : ', shape=box'
            @out.puts "  #{id} [label=#{dot_string(label.(node))}#{shape}];"
          end
          graph.edges.each do |edge|
            style = edge.call.lazy ? ' [style=dashed]' : ''
            @out.puts "  #{ids[source.(edge)]} -> #{ids[target.(edge)]}#{style};"
          end
          @out.puts '}'
        else
          @out.puts 'flowchart LR'
          ids.each do |node, id|
            text = label.(node).gsub('"', '#quot;')
            @out.puts node ? "  #{id}[\"#{text}\"]" : "  #{id}([\"#{text}\"])"
          end
          graph.edges.each do |edge|
            arrow = edge.call.lazy ? '-.->' : '-->'
            @out.puts "  #{ids[source.(edge)]} #{arrow} #{ids[target.(edge)]}"
          end
        end
        0
      end

      def dot_string(text) = "\"#{text.gsub(/["\\]/) { |c| "\\#{c}" }}\""

      # The shortest chain of imports from FROM, a file the app or a Carton
      # runs, to the Carton that holds TO. Exits 1 when there is none.
      def why(args)
        project, from, to = project(args, 'why', operands: %w[FROM TO])
        return 2 unless project

        start = project.owner(File.realpath(from))&.entrypoint
        goal = project.carton_containing(File.realpath(to))&.entrypoint
        path = goal && ImportGraph.new(project).path(start, goal)
        unless path
          @out.puts "#{from} does not import #{to}"
          return 1
        end

        path.each do |edge|
          call = edge.call
          @out.puts "#{project.relative(call.file)}:#{call.line}:#{call.column}: " \
                      "#{call.kind} '#{call.path}' -> #{project.label(edge.carton)}"
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

      # `file:line:column: level: message [rule]`, like a compiler, then
      # the counts.
      def print_text(project, problems, summary)
        problems.each do |problem|
          @out.puts "#{project.relative(problem.file)}:#{problem.line}:" \
                      "#{problem.column}: #{problem.level}: " \
                      "#{project.relative(problem.message)} [#{problem.rule}]"
        end
        @out.puts summary
                    .map { |key, count| count(count, NOUNS.fetch(key)) }
                    .join(', ')
      end

      NOUNS = {
        files: 'file',
        cartons: 'Carton',
        errors: 'error',
        warnings: 'warning',
      }.freeze
      private_constant :NOUNS

      def count(number, noun) = "#{number} #{noun}#{'s' unless number == 1}"

      # The JSON report's `version` changes only when a field is removed or
      # changes meaning.
      def print_json(project, problems, summary)
        list =
          problems.map do |problem|
            {
              level: problem.level,
              rule: problem.rule,
              file: project.relative(problem.file),
              line: problem.line,
              column: problem.column,
              message: project.relative(problem.message),
            }
          end
        @out.puts JSON.pretty_generate(version: 1, problems: list, **summary)
      end

      # Parse options shared by every command, then scan PATHs. Named imports
      # resolve against `-I` directories, then this process's `$LOAD_PATH`,
      # which includes the bundle's gems under `bundle exec`, and files belong
      # to the gems RubyGems knows: the bundle's, or every installed gem.
      # `why` takes exactly FROM and TO and reads only FROM, so its
      # `operands` are returned instead of scanned.
      def project(args, command, operands: nil)
        includes = []
        exclude = []
        parser =
          OptionParser.new do |o|
            o.program_name = 'carton'
            o.version = VERSION
            o.banner =
              "Usage: carton #{command} [options] #{operands&.join(' ') || 'PATH...'}"
            o.on(
              '-I',
              '--include DIR',
              'Add DIR to the load path for named imports',
            ) { |dir| includes << File.expand_path(dir) }
            unless operands
              o.on(
                '--exclude GLOB',
                'Skip matching files in directory PATHs (and vendor/bundle)',
              ) { |glob| exclude << glob }
            end
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
        if operands ? paths.size != operands.size : paths.empty?
          @err.puts parser
          return
        end

        load_path = includes + $LOAD_PATH
        return Project.new(paths, load_path:, exclude:) unless operands

        [Project.new(paths.first(1), load_path:), *paths]
      end
    end
  end
end
