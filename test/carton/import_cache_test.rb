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

  # The cache's lock is not held while an Entrypoint runs, so its threads
  # can import other Cartons.
  def test_entrypoint_threads_can_import_other_cartons
    other = FEATURE.sub('single_export', 'hash_export')
    cache =
      ImportCache.new do |t|
        next :other if t.feature == other

        thread = Thread.new { cache.import(Target.new(feature: other)) }
        thread.join(5) ? thread.value : :timed_out
      end

    assert_equal :other, cache.import(Target.new(feature: FEATURE))
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

    first = Thread.new { cache.import(target) }
    started.pop
    second = Thread.new { cache.import(target) }
    sleep 0.05 until second.status == 'sleep'
    release << true

    assert_equal %i[value value], [first, second].map(&:value)
    assert_equal 1, loads
  end

  def test_reentrant_import_on_one_thread_is_circular
    cache = ImportCache.new { cache.import(target) }

    error = assert_raises(Carton::ImportError) { cache.import(target) }
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

    first = Thread.new { cache.import(target) }
    started.pop
    second = Thread.new { cache.import(target) }
    sleep 0.05 until second.status == 'sleep'
    release << true

    assert_raises(RuntimeError) { first.value }
    assert_equal :second, second.value
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
