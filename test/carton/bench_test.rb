# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'
require 'rbconfig'

# Keeps bench/scale.rb working; `rake bench` runs the full sizes.
class BenchTest < Minitest::Test
  ROOT = File.expand_path('../..', __dir__)

  def test_quick_benchmark_prints_its_tables
    clean =
      ENV.keys.grep(/\A(BUNDLER?_|RUBY(OPT|LIB)\z)/).to_h { |key| [key, nil] }
    output, status =
      Open3.capture2e(
        clean,
        RbConfig.ruby,
        File.join(ROOT, 'bench/scale.rb'),
        '--quick',
      )

    assert status.success?, output
    assert_match(/^## Plain Cartons$/, output)
    assert_match(/^\| 5 \| [\d.]+ \| [\d.]+ \| [\d.]+ \| [\d.]+ \|$/, output)
    assert_match(/^## Gem Cartons$/, output)
    assert_match(/^\| 6 \| [\d.]+ \| [\d.]+ \| [\d.]+ \|$/, output)
  end
end
