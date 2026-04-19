# frozen_string_literal: true

require_relative '../test_helper'

class CartonTest < Minitest::Test
  def test_export_default_is_available_globally
    assert_respond_to TOPLEVEL_BINDING.receiver, :export_default
  end

  def test_with_bundle_sets_bundle_gemfile_and_clears_stale_lockfile
    previous = ENV['BUNDLE_GEMFILE']
    previous_lockfile = ENV['BUNDLE_LOCKFILE']
    gemfile = File.expand_path('../fixtures/with_bundle/Gemfile', __dir__)
    stale_lockfile = '/tmp/carton-stale.lock'
    ENV['BUNDLE_LOCKFILE'] = stale_lockfile
    result =
      Carton.with_bundle(gemfile) do
        [ENV['BUNDLE_GEMFILE'], ENV['BUNDLE_LOCKFILE']]
      end

    assert_equal [gemfile, nil], result
    if previous
      assert_equal previous, ENV['BUNDLE_GEMFILE']
    else
      assert_nil ENV['BUNDLE_GEMFILE']
    end

    assert_equal stale_lockfile, ENV['BUNDLE_LOCKFILE']
  ensure
    if previous
      ENV['BUNDLE_GEMFILE'] = previous
    else
      ENV.delete 'BUNDLE_GEMFILE'
    end

    if previous_lockfile
      ENV['BUNDLE_LOCKFILE'] = previous_lockfile
    else
      ENV.delete 'BUNDLE_LOCKFILE'
    end
  end

  def test_with_bundle_restores_bundle_env_after_error
    previous = ENV['BUNDLE_GEMFILE']
    previous_lockfile = ENV['BUNDLE_LOCKFILE']
    gemfile = File.expand_path('../fixtures/with_bundle/Gemfile', __dir__)
    stale_lockfile = '/tmp/carton-stale.lock'
    ENV['BUNDLE_LOCKFILE'] = stale_lockfile

    error =
      assert_raises(RuntimeError) do
        Carton.with_bundle(gemfile) { raise 'boom' }
      end

    assert_equal 'boom', error.message
    if previous
      assert_equal previous, ENV['BUNDLE_GEMFILE']
    else
      assert_nil ENV['BUNDLE_GEMFILE']
    end

    assert_equal stale_lockfile, ENV['BUNDLE_LOCKFILE']
  ensure
    if previous
      ENV['BUNDLE_GEMFILE'] = previous
    else
      ENV.delete 'BUNDLE_GEMFILE'
    end

    if previous_lockfile
      ENV['BUNDLE_LOCKFILE'] = previous_lockfile
    else
      ENV.delete 'BUNDLE_LOCKFILE'
    end
  end
end
