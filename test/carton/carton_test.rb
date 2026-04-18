# frozen_string_literal: true

require_relative '../test_helper'

class CartonTest < Minitest::Test
  def test_export_default_is_available_globally
    assert_respond_to TOPLEVEL_BINDING.receiver, :export_default
  end

  def test_with_bundle_sets_and_restores_bundle_gemfile
    previous = ENV['BUNDLE_GEMFILE']
    previous_lockfile = ENV['BUNDLE_LOCKFILE']
    gemfile = File.expand_path('../fixtures/with_bundle/Gemfile', __dir__)
    lockfile = "#{gemfile}.lock"
    result =
      Carton.with_bundle(gemfile) do
        [ENV['BUNDLE_GEMFILE'], ENV['BUNDLE_LOCKFILE']]
      end

    assert_equal [gemfile, lockfile], result
    if previous
      assert_equal previous, ENV['BUNDLE_GEMFILE']
    else
      assert_nil ENV['BUNDLE_GEMFILE']
    end

    if previous_lockfile
      assert_equal previous_lockfile, ENV['BUNDLE_LOCKFILE']
    else
      assert_nil ENV['BUNDLE_LOCKFILE']
    end
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

  def test_with_bundle_restores_bundle_gemfile_after_error
    previous = ENV['BUNDLE_GEMFILE']
    previous_lockfile = ENV['BUNDLE_LOCKFILE']
    gemfile = File.expand_path('../fixtures/with_bundle/Gemfile', __dir__)

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

    if previous_lockfile
      assert_equal previous_lockfile, ENV['BUNDLE_LOCKFILE']
    else
      assert_nil ENV['BUNDLE_LOCKFILE']
    end
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
