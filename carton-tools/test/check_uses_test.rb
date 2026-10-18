# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'stringio'
require 'tmpdir'

# Checks that follow how an import's result is used.
class CheckUsesTest < Minitest::Test
  MATH = "export add: 1, PI: 3.14\n"

  # Only `fetch` and `=>` patterns raise for a missing key of an exported
  # Hash.
  def test_missing_hash_keys_are_errors
    main = <<~RUBY
      MathTools = import_relative 'math'
      MathTools.fetch(:add)
      MathTools.fetch(:PI)
      MathTools.fetch(:gone)
    RUBY

    status, output = check('main.rb' => main, 'math.rb' => MATH)

    assert_equal 1, status
    assert_equal [missing(4, 'MathTools.fetch(:gone)', 'gone')], errors(output)
  end

  # `[]`, `key?` and `in` patterns return nil or false instead of raising.
  def test_non_raising_lookups_are_fine
    main = <<~RUBY
      MathTools = import_relative 'math'
      MathTools[:nope]
      MathTools.key?(:nope)
      MathTools.fetch(:nope, nil)
      MathTools.keys
      case MathTools
      in { nope: } then 1
      end
    RUBY

    status, output = check('main.rb' => main, 'math.rb' => MATH)

    assert_equal 0, status, output
  end

  def test_local_variables_and_patterns_are_followed
    main = <<~RUBY
      math = import_relative 'math'
      math.fetch(:nope)
      import_relative('math') => { add:, missing: }
      math => { pi: }
    RUBY

    _, output = check('main.rb' => main, 'math.rb' => MATH)

    pattern = "import_relative('math') => { missing: }"
    expected = [
      missing(2, 'math.fetch(:nope)', 'nope'),
      missing(3, pattern, 'missing'),
      missing(4, 'math.fetch(:pi)', 'pi'),
    ]
    assert_equal expected, errors(output)
  end

  # A reassigned local could hold anything, so it is not followed.
  def test_reassigned_locals_are_not_followed
    main = "math = import_relative 'math'\nmath = other\nmath.fetch(:nope)\n"

    assert_equal 0, check('main.rb' => main, 'math.rb' => MATH).first
  end

  # Constants are shared by the files of one Box, and resolve lexically.
  def test_constant_bindings_resolve_across_files_and_namespaces
    files = {
      'main.rb' =>
        "module App\n  MathTools = import_relative 'math'\nend\nrequire_relative 'use'\n",
      'use.rb' =>
        "module App\n  MathTools.fetch(:nope)\nend\nApp::MathTools.fetch(:gone)\n",
      'math.rb' => MATH,
    }

    _, output = check(files)

    expected = [
      missing(2, 'MathTools.fetch(:nope)', 'nope', file: 'use.rb'),
      missing(4, 'App::MathTools.fetch(:gone)', 'gone', file: 'use.rb'),
    ]
    assert_equal expected, errors(output)
  end

  # Their names are not declared in one place.
  def test_default_exports_and_bare_cartons_are_not_checked
    main = <<~RUBY
      Billing = import_relative 'billing'
      Billing.anything
      Util = import_relative 'util'
      Util.anything
    RUBY
    files = {
      'main.rb' => main,
      'billing.rb' => "module Billing; end\nexport Billing\n",
      'util.rb' => "def helper = 1\n",
    }

    assert_equal 0, check(files).first
  end

  # Code that rescues what a use raises is not certain to fail.
  def test_rescued_uses_are_not_errors
    main = <<~RUBY
      MathTools = import_relative 'math'
      begin
        MathTools.fetch(:nope)
      rescue KeyError
        nil
      end
      MathTools.fetch(:gone) rescue nil
      begin
        MathTools.fetch(:other)
      rescue NameError
        nil
      end
    RUBY

    _, output = check('main.rb' => main, 'math.rb' => MATH)

    assert_equal [missing(9, 'MathTools.fetch(:other)', 'other')],
                 errors(output)
  end

  def test_private_constant_of_an_exported_module_is_an_error
    main = <<~RUBY
      Billing = import_relative 'billing'
      Billing::Invoice
      Billing::Tax.rate
    RUBY
    billing = <<~RUBY
      module Billing
        Invoice = 1
        module Tax; end
        private_constant :Tax
      end
      export Billing
    RUBY

    status, output = check('main.rb' => main, 'billing.rb' => billing)

    assert_equal 1, status
    expected =
      'main.rb:3: error: Billing::Tax is a private constant of the billing Carton'
    assert_equal [expected], errors(output)
  end

  private

  def missing(line, code, name, file: 'main.rb')
    "#{file}:#{line}: error: #{code}: the math Carton's export has no key " \
      "#{name} (it has add, PI)"
  end

  def errors(output) = output.lines(chomp: true).grep(/: error: /)

  def check(files, *)
    Dir.mktmpdir do |dir|
      files.each do |path, source|
        FileUtils.mkdir_p(File.dirname(File.join(dir, path)))
        File.write(File.join(dir, path), source)
      end
      out = StringIO.new
      status =
        Dir.chdir(dir) do
          Carton::Tools::CLI.start(
            ['check', *, 'main.rb'],
            out:,
            err: StringIO.new,
          )
        end
      [status, out.string]
    end
  end
end
