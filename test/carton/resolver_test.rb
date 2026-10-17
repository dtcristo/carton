# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'tmpdir'

class ResolverTest < Minitest::Test
  Resolver = Carton.const_get(:Resolver)
  FIXTURES = File.expand_path('../fixtures', __dir__)

  def test_resolves_absolute_path_with_or_without_extension
    expected = "#{FIXTURES}/single_export.rb"

    assert_equal expected, resolve("#{FIXTURES}/single_export").feature
    assert_equal expected, resolve(expected).feature
    assert_nil resolve(expected).load_path
  end

  def test_resolves_relative_to_base_dir
    target = resolve('single_export', base_dir: FIXTURES)

    assert_equal "#{FIXTURES}/single_export.rb", target.feature
    assert_nil target.load_path
  end

  def test_resolves_name_from_first_matching_load_path_entry
    target = resolve('single_export', load_path: ['/missing', FIXTURES])

    assert_equal "#{FIXTURES}/single_export.rb", target.feature
    assert_equal FIXTURES, target.load_path
  end

  # Like `require_relative`, a missing relative or absolute target never falls
  # back to a same-named feature elsewhere, such as the stdlib `json`.
  def test_missing_relative_path_raises_load_error
    error = assert_raises(LoadError) { resolve('json', base_dir: FIXTURES) }
    assert_equal "cannot load such file -- #{FIXTURES}/json", error.message
  end

  def test_missing_absolute_path_raises_load_error
    error = assert_raises(LoadError) { resolve("#{FIXTURES}/nope.rb") }
    assert_equal "cannot load such file -- #{FIXTURES}/nope.rb", error.message
  end

  def test_symlinked_load_path_entry_is_carried_as_given
    Dir.mktmpdir do |dir|
      link = File.join(dir, 'linked')
      File.symlink(FIXTURES, link)

      target = resolve('single_export', load_path: [link])

      assert_equal "#{link}/single_export.rb", target.feature
      assert_equal link, target.load_path
    end
  end

  def test_does_not_resolve_name_from_current_directory
    Dir.chdir(FIXTURES) do
      assert_equal 'single_export', resolve('single_export').feature
    end
  end

  def test_unresolved_name_returns_bare_path
    target = resolve('json', load_path: [FIXTURES])

    assert_equal 'json', target.feature
    assert_nil target.load_path
  end

  def test_earlier_native_extension_shadows_later_ruby_file
    Dir.mktmpdir do |dir|
      native = File.join(dir, 'native')
      Dir.mkdir(native)
      File.write(
        File.join(native, "single_export.#{RbConfig::CONFIG['DLEXT']}"),
        '',
      )

      target = resolve('single_export', load_path: [native, FIXTURES])

      assert_equal 'single_export', target.feature
    end
  end

  # A Carton is its Entrypoint `billing.rb` plus the `billing/` directory
  # beside it, so only the Entrypoint can be imported.
  def test_resolves_a_carton_entrypoint
    with_unit do |lib|
      assert_equal "#{lib}/billing.rb",
                   resolve('billing', load_path: [lib]).feature
    end
  end

  def test_name_inside_a_carton_raises_import_error
    with_unit do |lib|
      error =
        assert_raises(Carton::ImportError) do
          resolve('billing/invoice', load_path: [lib])
        end
      assert_equal "billing/invoice is inside the billing Carton: import 'billing', " \
                     'or require it from inside that Carton',
                   error.message
    end
  end

  def test_path_inside_a_carton_raises_import_error
    with_unit do |lib|
      error =
        assert_raises(Carton::ImportError) do
          resolve('billing/invoice', base_dir: lib)
        end
      assert_equal "#{lib}/billing/invoice.rb is inside the Carton #{lib}/billing.rb: " \
                     'import that file, or require it from inside that Carton',
                   error.message
    end
  end

  def test_nested_file_belongs_to_the_outermost_carton
    with_unit do |lib|
      File.write("#{lib}/billing/invoice.rb", '')
      FileUtils.mkdir_p("#{lib}/billing/invoice")
      File.write("#{lib}/billing/invoice/line.rb", '')

      error =
        assert_raises(Carton::ImportError) do
          resolve('billing/invoice/line', load_path: [lib])
        end
      assert_match(/inside the billing Carton: import 'billing'/, error.message)
    end
  end

  # Zeitwerk implicit namespaces: billing/models/ has no models.rb, but it is
  # still inside the billing Carton.
  def test_implicit_namespace_directory_belongs_to_its_carton
    with_unit do |lib|
      FileUtils.mkdir_p("#{lib}/billing/models")
      File.write("#{lib}/billing/models/invoice.rb", '')

      error =
        assert_raises(Carton::ImportError) do
          resolve('billing/models/invoice', load_path: [lib])
        end
      assert_match(/inside the billing Carton: import 'billing'/, error.message)
    end
  end

  # A Carton laid out like a gem can be imported by its root directory.
  def test_resolves_a_gem_shaped_directory_to_its_entrypoint
    Dir.mktmpdir do |dir|
      lib = File.join(File.realpath(dir), 'components/billing/lib')
      FileUtils.mkdir_p(lib)
      File.write("#{lib}/billing.rb", '')

      target = resolve('components/billing', base_dir: File.realpath(dir))

      assert_equal "#{lib}/billing.rb", target.feature
    end
  end

  def test_directory_without_lib_entrypoint_raises_load_error
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p("#{dir}/empty")
      assert_raises(LoadError) { resolve('empty', base_dir: dir) }
    end
  end

  # rack-test ships lib/rack/test.rb without a lib/rack.rb of its own, so
  # rack/test is a Carton even though another gem defines rack.rb.
  def test_directory_without_a_sibling_entrypoint_is_not_a_carton
    with_unit do |lib|
      FileUtils.mkdir_p("#{lib}/rack")
      File.write("#{lib}/rack/test.rb", '')

      assert_equal "#{lib}/rack/test.rb",
                   resolve('rack/test', load_path: [lib]).feature
    end
  end

  private

  def resolve(path, load_path: [], base_dir: nil)
    Resolver.resolve(path, load_path:, base_dir:)
  end

  def with_unit
    Dir.mktmpdir do |dir|
      lib = File.join(File.realpath(dir), 'lib')
      FileUtils.mkdir_p("#{lib}/billing")
      File.write("#{lib}/billing.rb", '')
      File.write("#{lib}/billing/invoice.rb", '')
      yield lib
    end
  end
end
