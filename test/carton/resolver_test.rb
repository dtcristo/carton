# frozen_string_literal: true

require_relative '../test_helper'
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

  private

  def resolve(path, load_path: [], base_dir: nil)
    Resolver.resolve(path, load_path:, base_dir:)
  end
end
