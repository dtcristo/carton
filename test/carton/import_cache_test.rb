# frozen_string_literal: true

require_relative '../test_helper'

class ImportCacheTest < Minitest::Test
  ImportCache = Carton.const_get(:ImportCache)
  Target = Carton.const_get(:Resolver)::Target
  Spec = Struct.new(:name, :version)
  FEATURE = File.expand_path('../fixtures/single_export.rb', __dir__)

  def setup
    @loads = 0
    @cache = ImportCache.new { @loads += 1 }
  end

  def test_reuses_entry_when_shared_gem_versions_agree
    @cache.import(target('bigdecimal' => '3.3.1'))
    @cache.import(target('bigdecimal' => '3.3.1', 'json' => '2.0.0'))
    @cache.import(target)

    assert_equal 1, @loads
  end

  def test_raises_when_import_activates_a_different_gem_version
    @cache.import(target('bigdecimal' => '3.3.1'))

    error =
      assert_raises(Carton::ImportError) do
        @cache.import(target('bigdecimal' => '4.1.1'))
      end
    assert_match(/imported with bigdecimal 3\.3\.1/, error.message)
    assert_match(/activates bigdecimal 4\.1\.1/, error.message)
  end

  # Locked gems the Carton loaded count too, not only its declared closure.
  def test_raises_when_import_locks_another_version_of_a_used_gem
    first = target
    first.gem_usage = -> { [Spec.new('bigdecimal', '3.3.1')] }
    @cache.import(first)

    error =
      assert_raises(Carton::ImportError) do
        @cache.import(locked_target('bigdecimal' => '4.1.1'))
      end
    assert_match(/imported with bigdecimal 3\.3\.1/, error.message)
  end

  # A locked gem the Carton never loaded may differ between importers.
  def test_ignores_locked_gems_the_carton_did_not_use
    first = target
    first.gem_usage = -> { [] }
    @cache.import(first)
    @cache.import(locked_target('json' => '2.0.0'))

    assert_equal 1, @loads
  end

  private

  def locked_target(versions)
    Target.new(
      feature: FEATURE,
      gems: [],
      locked_gems: versions.map { |name, version| Spec.new(name, version) },
    )
  end

  def target(versions = {})
    Target.new(
      feature: FEATURE,
      gems: versions.map { |name, version| Spec.new(name, version) },
    )
  end
end
