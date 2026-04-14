# frozen_string_literal: true

require_relative '../test_helper'

class PackageTest < Minitest::Test
  def test_with_bundle_sets_and_restores_bundle_gemfile
    previous = ENV['BUNDLE_GEMFILE']
    result = Package.with_bundle('/tmp/demo/Gemfile') { ENV['BUNDLE_GEMFILE'] }

    assert_equal '/tmp/demo/Gemfile', result
    assert_equal previous, ENV['BUNDLE_GEMFILE']
  ensure
    if previous
      ENV['BUNDLE_GEMFILE'] = previous
    else
      ENV.delete 'BUNDLE_GEMFILE'
    end
  end

  def test_with_bundle_restores_bundle_gemfile_after_error
    previous = ENV['BUNDLE_GEMFILE']

    error =
      assert_raises(RuntimeError) do
        Package.with_bundle('/tmp/demo/Gemfile') { raise 'boom' }
      end

    assert_equal 'boom', error.message
    assert_equal previous, ENV['BUNDLE_GEMFILE']
  ensure
    if previous
      ENV['BUNDLE_GEMFILE'] = previous
    else
      ENV.delete 'BUNDLE_GEMFILE'
    end
  end
end
