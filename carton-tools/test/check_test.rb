# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'stringio'
require 'tmpdir'

class CheckTest < Minitest::Test
  EXAMPLES = File.expand_path('../../examples', __dir__)

  def test_clean_project_passes
    status, output =
      check(
        'main.rb' => "Billing = import_relative 'billing'\nBilling\n",
        'billing.rb' => "require_relative 'billing/tax'\nexport Billing\n",
        'billing/tax.rb' => "module Billing; end\n",
      )

    assert_equal 0, status
    assert_equal "3 files, 1 Carton, 0 errors, 0 warnings\n", output
  end

  def test_missing_relative_import_is_an_error
    status, output = check('main.rb' => "import_relative 'nope'\n")

    assert_equal 1, status
    assert_match(
      %r{^main\.rb:1:1: error: cannot load such file -- nope \(tried nope\.rb and nope/lib/nope\.rb in \.\) \[import-error\]$},
      output,
    )
  end

  def test_name_not_on_the_load_path_is_a_warning
    status, output = check('main.rb' => "import 'some_gem'\n")

    assert_equal 0, status
    assert_match(
      /^main\.rb:1:1: warning: cannot find some_gem on the load path/,
      output,
    )
  end

  def test_include_option_resolves_named_imports
    status, output =
      check(
        { 'main.rb' => "import 'tool'\n", 'lib/tool.rb' => "export({})\n" },
        '-I',
        'lib',
      )

    assert_equal 0, status
    assert_match(/1 Carton, 0 errors, 0 warnings/, output)
  end

  # The directory scan reads x/lib/x/helper.rb before z.rb imports the
  # gem-shaped x, whose lib/ then resolves helper's named import.
  def test_file_read_before_its_carton_resolves_with_the_carton_load_path
    Dir.mktmpdir do |dir|
      {
        'z.rb' => "X = import_relative 'x'\np X\n",
        'x/lib/x.rb' => "require_relative 'x/helper'\nexport 1\n",
        'x/lib/x/helper.rb' => "Y = import 'y'\np Y\n",
        'x/lib/y.rb' => "export 2\n",
      }.each do |path, source|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), source)
      end
      status, output = run_cli(dir, 'check', '.')

      assert_equal 0, status
      assert_match(/2 Cartons, 0 errors, 0 warnings/, output)
    end
  end

  def test_strict_fails_on_warnings
    files = { 'main.rb' => "import_relative(ENV['X'])\n" }

    assert_equal 0, check(files).first
    assert_equal 1, check(files, '--strict').first
  end

  # `# carton:dynamic`, on the import's line or the line above, marks an
  # intended dynamic import.
  def test_dynamic_marker_silences_import_warnings
    main = <<~RUBY
      import_relative(ENV['X']) # carton:dynamic
      # carton:dynamic
      import 'some_gem'
    RUBY

    status, output = check({ 'main.rb' => main }, '--strict')

    assert_equal 0, status, output
    assert_match(/0 errors, 0 warnings/, output)
  end

  def test_dynamic_import_is_a_warning
    status, output = check('main.rb' => "import_relative(ENV['X'])\n")

    assert_equal 0, status
    assert_match(
      /^main\.rb:1:1: warning: import_relative path is not a literal/,
      output,
    )
  end

  def test_importing_a_file_inside_a_carton_is_an_error
    status, output =
      check(
        'main.rb' => "import_relative 'billing/tax'\n",
        'billing.rb' => '',
        'billing/tax.rb' => '',
      )

    assert_equal 1, status
    assert_match(
      %r{^main\.rb:1:1: error: billing/tax\.rb is inside the Carton billing\.rb},
      output,
    )
  end

  def test_eager_import_cycle_is_an_error
    status, output =
      check(
        'main.rb' => "import_relative 'a'\n",
        'a.rb' => "import_relative 'b'\nexport({})\n",
        'b.rb' => "import_relative 'a'\nexport({})\n",
      )

    assert_equal 1, status
    assert_match(
      /^a\.rb:1:1: error: import cycle: a\.rb -> b\.rb -> a\.rb \[import-cycle\]$/,
      output,
    )
    assert_equal 1, output.scan('import cycle').size
  end

  def test_lazy_import_cycle_is_a_warning
    status, output =
      check(
        'main.rb' => "import_relative 'a'\n",
        'a.rb' => "import_relative 'b'\nexport({})\n",
        'b.rb' => "def a = import_relative('a')\nexport({})\n",
      )

    assert_equal 0, status
    assert_match(
      /warning: import cycle: a\.rb -> b\.rb -> a\.rb \(an import runs lazily/,
      output,
    )
  end

  def test_longer_cycles_are_each_reported_once
    status, output =
      check(
        'main.rb' => "import_relative 'a'\nimport_relative 'x'\n",
        'a.rb' => "import_relative 'b'\nexport({})\n",
        'b.rb' => "import_relative 'c'\nexport({})\n",
        'c.rb' => "import_relative 'a'\nexport({})\n",
        'x.rb' => "import_relative 'y'\nexport({})\n",
        'y.rb' => "import_relative 'x'\nexport({})\n",
      )

    assert_equal 1, status
    assert_match(
      /^a\.rb:1:1: error: import cycle: a\.rb -> b\.rb -> c\.rb -> a\.rb \[import-cycle\]$/,
      output,
    )
    assert_match(
      /^x\.rb:1:1: error: import cycle: x\.rb -> y\.rb -> x\.rb \[import-cycle\]$/,
      output,
    )
    assert_equal 2, output.scan('import cycle').size
  end

  def test_an_eager_cycle_wins_over_a_shorter_lazy_one
    status, output =
      check(
        'main.rb' => "import_relative 'a'\n",
        'a.rb' => "import_relative 'b'\nexport({})\n",
        'b.rb' =>
          "def a = import_relative('a')\nimport_relative 'c'\nexport({})\n",
        'c.rb' => "import_relative 'a'\nexport({})\n",
      )

    assert_equal 1, status
    assert_match(
      /^a\.rb:1:1: error: import cycle: a\.rb -> b\.rb -> c\.rb -> a\.rb \[import-cycle\]$/,
      output,
    )
    assert_equal 1, output.scan('import cycle').size
  end

  def test_a_large_acyclic_graph_is_checked_quickly
    files = { 'main.rb' => "X = import_relative 'c0'\np X\n" }
    200.times do |i|
      files["c#{i}.rb"] = "A = import_relative 'c#{i + 1}'\n" \
        "B = import_relative 'c#{i + 2}'\n" \
        "export({ a: A, b: B })\n"
    end
    files['c200.rb'] = files['c201.rb'] = "export 1\n"

    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status, output = check(files)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

    assert_equal 0, status, output
    assert_operator elapsed, :<, 10
  end

  # From app/, ../app-x shares app's prefix but is outside it, and two
  # Cartons share the basename billing.
  def test_paths_beside_the_working_directory_keep_their_names
    Dir.mktmpdir do |root|
      root = File.realpath(root)
      {
        'app/main.rb' =>
          "X = import_relative '../app-x/a/billing'\n" \
            "import_relative '../app-x/missing'\nputs X\n",
        'app-x/a/billing.rb' =>
          "B2 = import_relative '../b/billing'\nexport B2\n",
        'app-x/b/billing.rb' =>
          "B1 = import_relative '../a/billing'\nexport B1\n",
      }.each do |path, source|
        FileUtils.mkdir_p(File.dirname(File.join(root, path)))
        File.write(File.join(root, path), source)
      end
      _, output = run_cli(File.join(root, 'app'), 'check', 'main.rb')

      assert_includes output,
                      "cannot load such file -- #{root}/app-x/missing " \
                        "(tried missing.rb and missing/lib/missing.rb in #{root}/app-x)"
      assert_includes output,
                      'import cycle: ../app-x/a/billing.rb -> ' \
                        '../app-x/b/billing.rb -> ../app-x/a/billing.rb'
    end
  end

  def test_requiring_an_imported_carton_is_an_error
    status, output =
      check(
        'main.rb' => "import_relative 'math'\nrequire_relative 'billing'\n",
        'billing.rb' =>
          "require_relative 'math'\nrequire_relative 'billing/tax'\n",
        'billing/tax.rb' => '',
        'math.rb' => "export({})\n",
      )

    assert_equal 1, status
    assert_includes output,
                    "billing.rb:1:1: error: require_relative 'math' loads a " \
                      "second copy of the math.rb Carton's Entrypoint: import it instead [second-copy]\n"
    # billing is never imported, so requiring it is ordinary Ruby.
    refute_match(/^main\.rb/, output)
  end

  def test_requiring_a_file_inside_an_imported_carton_is_an_error
    status, output =
      check(
        'main.rb' =>
          "import_relative 'billing'\nrequire_relative 'billing/tax'\n",
        'billing.rb' => "require_relative 'billing/tax'\nexport({})\n",
        'billing/tax.rb' => '',
      )

    assert_equal 1, status
    assert_match(
      /^main\.rb:2:1: error: .* billing\.rb Carton's file: import it instead \[second-copy\]$/,
      output,
    )
    refute_match(/^billing\.rb/, output)
  end

  def test_export_rules_match_the_runtime
    status, output =
      check(
        'main.rb' => "import_relative 'twice'\nimport_relative 'named'\n",
        'twice.rb' => "export 1\nexport a: 1\n",
        'named.rb' => "export def add(a, b) = a + b\n",
      )

    assert_equal 1, status
    assert_match(
      /^twice\.rb:2:1: error: export may be called only once per Entrypoint \[export-twice\]$/,
      output,
    )
    assert_match(
      /^named\.rb:1:1: error: export takes the value to export, not a name: /,
      output,
    )
  end

  def test_imported_entrypoint_without_export_is_an_error
    status, output =
      check(
        'main.rb' => "import_relative 'billing'\nimport_relative 'billing'\n",
        'billing.rb' => "module Billing; end\n",
      )

    assert_equal 1, status
    assert_match(
      /^billing\.rb:1:1: error: an imported Entrypoint must call export \[missing-export\]$/,
      output,
    )
    assert_match(/1 error, 0 warnings/, output)
  end

  def test_empty_imported_entrypoint_without_export_is_an_error
    status, output =
      check('main.rb' => "import_relative 'empty'\n", 'empty.rb' => '')

    assert_equal 1, status
    assert_match(
      /^empty\.rb:1:1: error: an imported Entrypoint must call export \[missing-export\]$/,
      output,
    )
  end

  def test_explicit_nil_and_false_exports_are_valid
    status, output =
      check(
        'main.rb' => "import_relative 'nothing'\nimport_relative 'disabled'\n",
        'nothing.rb' => "export nil\n",
        'disabled.rb' => "export false\n",
      )

    assert_equal 0, status, output
    assert_match(/0 errors, 0 warnings/, output)
  end

  def test_unimported_files_do_not_need_export
    status, output =
      check(
        'main.rb' => "require_relative 'helper'\n",
        'helper.rb' => "module Helper; end\n",
      )

    assert_equal 0, status, output
    assert_match(/0 Cartons, 0 errors, 0 warnings/, output)
  end

  def test_exports_in_namespace_bodies_and_called_methods_are_not_missing
    [
      "module Billing; export self; end\n",
      "def publish; export 1; end\npublish\n",
      "self.export 1\n",
    ].each do |source|
      status, output =
        check(
          'main.rb' => "import_relative 'billing'\n",
          'billing.rb' => source,
        )

      assert_equal 0, status, output
    end
  end

  def test_conditional_export_does_not_require_control_flow_proof
    status, output =
      check(
        'main.rb' => "import_relative 'conditional'\n",
        'conditional.rb' => "export false if ENV['ENABLED']\n",
      )

    assert_equal 0, status, output
  end

  # Export calls in different branches of one conditional never both run,
  # so they are not duplicates.
  def test_exclusive_branches_may_each_export
    exclusive = <<~RUBY
      if ENV['A']
        export 1
      elsif ENV['B']
        export 2
      else
        case ENV['C']
        when 'c' then export y: 1
        else export y: 2
        end
      end
    RUBY

    status, output =
      check(
        'main.rb' => "import_relative 'exclusive'\n",
        'exclusive.rb' => exclusive,
      )

    refute_match(/: error: /, output)
    assert_equal 0, status
  end

  # Calls that can both run still conflict, even inside one branch.
  def test_case_in_branches_may_each_export
    status, output =
      check(
        'main.rb' => "import_relative 'exclusive'\n",
        'exclusive.rb' =>
          "case ENV['A']\nin String then export 1\nin nil then export 3\nelse export 2\nend\n",
      )

    refute_match(/: error: /, output)
    assert_equal 0, status
  end

  def test_export_takes_exactly_one_value
    status, output =
      check(
        'main.rb' =>
          "import_relative 'none'\nimport_relative 'two'\n" \
            "import_relative 'splat'\n",
        'none.rb' => "export\n",
        'two.rb' => "A = 1\nB = 2\nexport A, B\n",
        'splat.rb' => "export(*[1])\n",
      )

    assert_equal 1, status
    assert_match(
      /^none\.rb:1:1: error: export takes exactly one value, not 0 \[export-arity\]$/,
      output,
    )
    assert_match(
      /^two\.rb:3:1: error: export takes exactly one value, not 2 \[export-arity\]$/,
      output,
    )
    refute_match(/^splat\.rb/, output)
  end

  def test_self_export_counts_as_export
    status, output =
      check(
        'main.rb' => "import_relative 'twice'\nimport_relative 'symbol'\n",
        'twice.rb' => "self.export 1\nexport 2\n",
        'symbol.rb' => "self.export :Billing\n",
      )

    assert_equal 1, status
    assert_match(
      /^twice\.rb:2:1: error: export may be called only once/,
      output,
    )
    assert_match(
      /^symbol\.rb:1:1: error: export takes the value to export/,
      output,
    )
  end

  def test_calls_that_can_both_run_still_conflict
    both = <<~RUBY
      if ENV['A']
        export 1
        export 2
      end
      export 3
    RUBY

    _, output =
      check('main.rb' => "import_relative 'both'\n", 'both.rb' => both)

    assert_equal %w[3 5],
                 output.scan(
                   /^both\.rb:(\d+):\d+: error: export may be called only once/,
                 ).flatten
  end

  def test_export_inside_a_carton_is_a_warning
    status, output =
      check(
        'main.rb' => "import_relative 'billing'\n",
        'billing.rb' => "require_relative 'billing/tax'\nexport({})\n",
        'billing/tax.rb' => "export 1\n",
      )

    assert_equal 0, status
    assert_match(
      %r{^billing/tax\.rb:1:1: warning: export outside an Entrypoint does nothing},
      output,
    )
  end

  def test_an_interiors_export_does_not_satisfy_its_entrypoint
    status, output =
      check(
        'main.rb' => "import_relative 'billing'\n",
        'billing.rb' => "require_relative 'billing/tax'\n",
        'billing/tax.rb' => "export 1\n",
      )

    assert_equal 1, status
    assert_match(
      /^billing\.rb:1:1: error: an imported Entrypoint must call export \[missing-export\]$/,
      output,
    )
    assert_match(/1 error, 1 warning/, output)
  end

  def test_parse_error_is_an_error
    status, output = check('main.rb' => "def broken(\n")

    assert_equal 1, status
    assert_match(/^main\.rb:1:1: error: /, output)
  end

  # Keep the working app clean and teach diagnostics in a separate file.
  def test_tooling_example_reports_its_deliberate_violations
    status, output = run_cli(EXAMPLES, 'check', 'tooling/violations.rb')

    assert_equal 1, status
    assert_includes output,
                    'Pricing::Tax is a private constant of the tooling/pricing.rb Carton'
    assert_includes output,
                    'tooling/pricing/tax.rb is inside ' \
                      'the Carton tooling/pricing.rb: import that file, or require ' \
                      'it from inside that Carton'
    assert_match(
      / files, 1 Carton, 2 errors, 0 warnings\z/,
      output.lines.last.chomp,
    )
  end

  def test_examples_with_relative_imports_are_clean
    %w[
      minimal
      tooling
      exports
      dependency_injection
      plugins
      zeitwerk
    ].each do |name|
      status, output = run_cli(EXAMPLES, 'check', "#{name}/main.rb")

      assert_equal 0, status, output
      assert_match(/0 errors, 0 warnings/, output)
    end
  end

  def test_master_prelude_spike_is_clean
    spikes = File.expand_path('../../spikes', __dir__)
    status, output = run_cli(spikes, 'check', 'master_prelude/main.rb')

    assert_equal 0, status, output
    assert_match(/0 errors, 0 warnings/, output)
  end

  private

  def check(files, *)
    Dir.mktmpdir do |dir|
      files.each do |path, source|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), source)
      end
      run_cli(dir, 'check', *, 'main.rb')
    end
  end

  def run_cli(dir, *argv)
    out = StringIO.new
    err = StringIO.new
    status = Dir.chdir(dir) { Carton::Tools::CLI.start(argv, out:, err:) }
    assert_empty err.string
    [status, out.string]
  end
end
