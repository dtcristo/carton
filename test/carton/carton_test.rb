# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'
require 'rbconfig'

class CartonTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)

  def test_defines_its_version
    assert_match(/\A\d+\.\d+\.\d+/, Carton::VERSION)
  end

  # Carton is the runtime every Carton gem depends on, so it must load
  # without RubyGems.
  def test_imports_without_rubygems
    fixture = File.join(ROOT, 'test/fixtures/single_export.rb')
    output, error, status =
      Open3.capture3(
        { 'RUBY_BOX' => '1', 'RUBYOPT' => nil, 'RUBYLIB' => nil },
        RbConfig.ruby,
        '--disable-gems',
        '-Ilib',
        '-e',
        "require 'carton'; p defined?(Gem); puts import(#{fixture.inspect}).name",
        chdir: ROOT,
      )

    assert status.success?, error
    assert_equal "nil\nUser\n", output
  end

  # One rescue target for every error Carton raises itself.
  def test_errors_share_one_base_class
    assert_operator Carton::Error, :<, StandardError
    assert_operator Carton::ImportError, :<, Carton::Error
    assert_operator Carton::ExportError, :<, Carton::Error
    assert_operator Carton::GemfileNotFound, :<, Carton::Error
  end
end
