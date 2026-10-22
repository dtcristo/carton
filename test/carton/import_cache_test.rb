# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'

class ImportCacheTest < Minitest::Test
  ImportCache = Carton.const_get(:ImportCache)
  Target = Carton.const_get(:Resolver)::Target
  Spec = Struct.new(:name, :version)
  # Stands in for a loaded Carton Box.
  FakeBox = Struct.new(:export, :used_gems)
  FEATURE = File.expand_path('../fixtures/single_export.rb', __dir__)
  TARGET = Target.new(feature: FEATURE)

  def setup
    @loads = 0
    @used_gems = nil
    @cache =
      ImportCache.new do |_target, gems:, **|
        @loads += 1
        FakeBox.new(:value, @used_gems || gems)
      end
  end

  def test_returns_the_cached_box
    first = @cache.import(TARGET)

    assert_same first, @cache.import(TARGET)
    assert_equal :value, first.export
  end

  def test_reuses_entry_when_shared_gem_versions_agree
    @cache.import(TARGET, gems: specs('bigdecimal' => '3.3.1'))
    @cache.import(
      TARGET,
      gems: specs('bigdecimal' => '3.3.1', 'json' => '2.0.0'),
    )
    @cache.import(TARGET)

    assert_equal 1, @loads
  end

  def test_raises_when_import_activates_a_different_gem_version
    @cache.import(TARGET, gems: specs('bigdecimal' => '3.3.1'))

    error =
      assert_raises(Carton::ImportError) do
        @cache.import(TARGET, gems: specs('bigdecimal' => '4.1.1'))
      end
    assert_match(/imported with bigdecimal 3\.3\.1/, error.message)
    assert_match(/activates bigdecimal 4\.1\.1/, error.message)
  end

  # Locked gems the Carton loaded count too, not only its declared closure.
  def test_raises_when_import_locks_another_version_of_a_used_gem
    @used_gems = specs('bigdecimal' => '3.3.1')
    @cache.import(TARGET)

    error =
      assert_raises(Carton::ImportError) do
        @cache.import(TARGET, locked_gems: specs('bigdecimal' => '4.1.1'))
      end
    assert_match(/imported with bigdecimal 3\.3\.1/, error.message)
    assert_match(/locks bigdecimal 4\.1\.1/, error.message)
  end

  # A locked gem the Carton never loaded may differ between importers.
  def test_ignores_locked_gems_the_carton_did_not_use
    @cache.import(TARGET)
    @cache.import(TARGET, locked_gems: specs('json' => '2.0.0'))

    assert_equal 1, @loads
  end

  # Entries are keyed by real path, so a symlinked Entrypoint shares one.
  def test_symlinked_entrypoint_shares_the_entry
    Dir.mktmpdir do |dir|
      link = File.join(dir, 'link.rb')
      File.symlink(FEATURE, link)

      assert_same @cache.import(TARGET),
                  @cache.import(Target.new(feature: link))
    end
  end

  # The cache's lock is not held while an Entrypoint runs, so its threads
  # can import other Cartons.
  def test_entrypoint_threads_can_import_other_cartons
    other = FEATURE.sub('single_export', 'hash_export')
    cache =
      ImportCache.new do |t, **|
        next :other if t.feature == other

        thread = Thread.new { cache.import(Target.new(feature: other)) }
        thread.join(5) ? thread.value : :timed_out
      end

    assert_equal :other, cache.import(TARGET)
  end

  # A second thread importing an Entrypoint that is still loading waits for
  # that load instead of starting another.
  def test_concurrent_imports_of_one_entrypoint_load_once
    started = Queue.new
    release = Queue.new
    loads = 0
    cache =
      ImportCache.new do
        loads += 1
        started << true
        release.pop
        :value
      end

    first = Thread.new { cache.import(TARGET) }
    started.pop
    second = Thread.new { cache.import(TARGET) }
    sleep 0.05 until second.status == 'sleep'
    release << true

    assert_equal %i[value value], [first, second].map(&:value)
    assert_equal 1, loads
  end

  def test_reentrant_import_on_one_thread_is_circular
    cache = ImportCache.new { cache.import(TARGET) }

    error = assert_raises(Carton::ImportError) { cache.import(TARGET) }
    assert_match(/\Acircular import: /, error.message)
  end

  # A thread waiting on a load that fails tries the load itself.
  def test_waiting_thread_retries_after_a_failed_load
    started = Queue.new
    release = Queue.new
    attempts = 0
    cache =
      ImportCache.new do
        attempts += 1
        next :second if attempts == 2

        started << true
        release.pop
        raise 'first load fails'
      end

    first =
      Thread.new do
        Thread.current.report_on_exception = false
        cache.import(TARGET)
      end
    started.pop
    second = Thread.new { cache.import(TARGET) }
    sleep 0.05 until second.status == 'sleep'
    release << true

    assert_raises(RuntimeError) { first.value }
    assert_equal :second, second.value
  end

  private

  def specs(versions)
    versions.map { |name, version| Spec.new(name, version) }
  end
end
