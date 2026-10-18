# frozen_string_literal: true

require_relative '../test_helper'
require 'carton/cli'
require 'fileutils'
require 'stringio'
require 'tmpdir'

class CheckTest < Minitest::Test
  EXAMPLES = File.expand_path('../../examples', __dir__)

  def test_clean_project_passes
    status, output =
      check(
        'main.rb' => "Billing = import_relative 'billing'\n",
        'billing.rb' =>
          "require_relative 'billing/tax'\nexport_default Billing\n",
        'billing/tax.rb' => "module Billing; end\n",
      )

    assert_equal 0, status
    assert_equal "3 files, 1 Cartons, 0 errors, 0 warnings\n", output
  end

  def test_missing_relative_import_is_an_error
    status, output = check('main.rb' => "import_relative 'nope'\n")

    assert_equal 1, status
    assert_match(
      %r{^main\.rb:1: error: cannot load such file -- nope \(tried nope\.rb and nope/lib/nope\.rb in \.\)$},
      output,
    )
  end

  def test_name_not_on_the_load_path_is_a_warning
    status, output = check('main.rb' => "import 'some_gem'\n")

    assert_equal 0, status
    assert_match(
      /^main\.rb:1: warning: cannot find some_gem on the load path/,
      output,
    )
  end

  def test_include_option_resolves_named_imports
    status, output =
      check(
        { 'main.rb' => "import 'tool'\n", 'lib/tool.rb' => '' },
        '-I',
        'lib',
      )

    assert_equal 0, status
    assert_match(/1 Cartons, 0 errors, 0 warnings/, output)
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
      /^main\.rb:1: warning: import_relative path is not a literal/,
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
      %r{^main\.rb:1: error: billing/tax\.rb is inside the Carton billing\.rb},
      output,
    )
  end

  def test_eager_import_cycle_is_an_error
    status, output =
      check(
        'main.rb' => "import_relative 'a'\n",
        'a.rb' => "import_relative 'b'\n",
        'b.rb' => "import_relative 'a'\n",
      )

    assert_equal 1, status
    assert_match(/^a\.rb:1: error: import cycle: a -> b -> a$/, output)
    assert_equal 1, output.scan('import cycle').size
  end

  def test_lazy_import_cycle_is_a_warning
    status, output =
      check(
        'main.rb' => "import_relative 'a'\n",
        'a.rb' => "import_relative 'b'\n",
        'b.rb' => "def a = import_relative('a')\n",
      )

    assert_equal 0, status
    assert_match(
      /warning: import cycle: a -> b -> a \(an import runs lazily/,
      output,
    )
  end

  def test_requiring_an_imported_carton_is_an_error
    status, output =
      check(
        'main.rb' => "import_relative 'math'\nrequire_relative 'billing'\n",
        'billing.rb' =>
          "require_relative 'math'\nrequire_relative 'billing/tax'\n",
        'billing/tax.rb' => '',
        'math.rb' => '',
      )

    assert_equal 1, status
    assert_includes output,
                    "billing.rb:1: error: require_relative 'math' loads a " \
                      "second copy of the math Carton's Entrypoint: import it instead\n"
    # billing is never imported, so requiring it is ordinary Ruby.
    refute_match(/^main\.rb/, output)
  end

  def test_requiring_a_file_inside_an_imported_carton_is_an_error
    status, output =
      check(
        'main.rb' =>
          "import_relative 'billing'\nrequire_relative 'billing/tax'\n",
        'billing.rb' => "require_relative 'billing/tax'\n",
        'billing/tax.rb' => '',
      )

    assert_equal 1, status
    assert_match(
      /^main\.rb:2: error: .* billing Carton's file: import it instead$/,
      output,
    )
    refute_match(/^billing\.rb/, output)
  end

  def test_export_rules_match_the_runtime
    status, output =
      check(
        'main.rb' => <<~RUBY,
          import_relative 'twice'
          import_relative 'mixed'
          import_relative 'repeated'
        RUBY
        'twice.rb' => "export_default 1\nexport_default 2\n",
        'mixed.rb' => "export_default 1\nexport a: 1\n",
        'repeated.rb' => "export a: 1\nexport a: 2\n",
      )

    assert_equal 1, status
    assert_match(
      /^mixed\.rb:2: error: export_default cannot be combined with export; /,
      output,
    )
    assert_match(
      /^repeated\.rb:2: error: export name given more than once: a$/,
      output,
    )
    assert_match(
      /^twice\.rb:2: error: export_default may be called only once per file$/,
      output,
    )
  end

  def test_export_shadowing_a_built_in_method_is_an_error
    status, output =
      check(
        'main.rb' => "import_relative 'named'\nimport_relative 'bare'\n",
        'named.rb' => "export fetch: 1, PI: 3\n",
        'bare.rb' => "def name = 'bare'\ndef helper = 1\n",
      )

    assert_equal 1, status
    assert_match(
      /^named\.rb:1: error: export name fetch would hide Carton::Exports#fetch/,
      output,
    )
    assert_match(
      /^bare\.rb:1: error: export name name would hide Carton::Exports#name/,
      output,
    )
    assert_equal 2, output.scan('would hide').size
  end

  def test_export_inside_a_carton_is_a_warning
    status, output =
      check(
        'main.rb' => "import_relative 'billing'\n",
        'billing.rb' => "require_relative 'billing/tax'\n",
        'billing/tax.rb' => "export :x\n",
      )

    assert_equal 0, status
    assert_match(
      %r{^billing/tax\.rb:1: warning: export outside an Entrypoint does nothing},
      output,
    )
  end

  def test_parse_error_is_an_error
    status, output = check('main.rb' => "def broken(\n")

    assert_equal 1, status
    assert_match(/^main\.rb:1: error: /, output)
  end

  # The minimal example imports a file inside billing on purpose, to show
  # the runtime error, so the check reports it too.
  def test_minimal_example_reports_its_deliberate_deep_import
    status, output = run_cli(EXAMPLES, 'check', 'minimal/main.rb')

    assert_equal 1, status
    problem, summary = output.lines(chomp: true)
    assert_equal 'minimal/main.rb:21: error: minimal/billing/invoice.rb is inside ' \
                   'the Carton minimal/billing.rb: import that file, or require ' \
                   'it from inside that Carton',
                 problem
    assert_match(/ files, 2 Cartons, 1 errors, 0 warnings\z/, summary)
  end

  def test_examples_without_bundles_are_clean
    %w[gems master_prelude].each do |name|
      status, output = run_cli(EXAMPLES, 'check', "#{name}/main.rb")

      assert_equal 0, status, output
      assert_match(/0 errors, 0 warnings/, output)
    end
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
    status = Dir.chdir(dir) { Carton::CLI.start(argv, out:, err:) }
    assert_empty err.string
    [status, out.string]
  end
end
