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
      assert_raises(RuntimeError) do
        @cache.import(target('bigdecimal' => '4.1.1'))
      end
    assert_match(/imported with bigdecimal 3\.3\.1/, error.message)
    assert_match(/activates bigdecimal 4\.1\.1/, error.message)
  end

  private

  def target(versions = {})
    Target.new(
      feature: FEATURE,
      gems: versions.map { |name, version| Spec.new(name, version) },
    )
  end
end
