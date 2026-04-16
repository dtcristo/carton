# frozen_string_literal: true

require_relative '../test_helper'

class CartonTest < Minitest::Test
  def test_export_default_is_available_globally
    assert_respond_to TOPLEVEL_BINDING.receiver, :export_default
  end

  def test_with_bundle_sets_and_restores_bundle_gemfile
    previous = ENV['BUNDLE_GEMFILE']
    result = Carton.with_bundle('/tmp/demo/Gemfile') { ENV['BUNDLE_GEMFILE'] }

    assert_equal '/tmp/demo/Gemfile', result
    if previous
      assert_equal previous, ENV['BUNDLE_GEMFILE']
    else
      assert_nil ENV['BUNDLE_GEMFILE']
    end
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
        Carton.with_bundle('/tmp/demo/Gemfile') { raise 'boom' }
      end

    assert_equal 'boom', error.message
    if previous
      assert_equal previous, ENV['BUNDLE_GEMFILE']
    else
      assert_nil ENV['BUNDLE_GEMFILE']
    end
  ensure
    if previous
      ENV['BUNDLE_GEMFILE'] = previous
    else
      ENV.delete 'BUNDLE_GEMFILE'
    end
  end
end
