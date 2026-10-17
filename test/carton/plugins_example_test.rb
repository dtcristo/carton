# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'
require 'rbconfig'

# Runs examples/plugins/main.rb as a real `RUBY_BOX=1` process outside the dev
# bundle, so each plugin sets up its own bundle as it would in an app.
class PluginsExampleTest < Minitest::Test
  MAIN = File.expand_path('../../examples/plugins/main.rb', __dir__)

  def test_each_plugin_runs_on_its_own_bigdecimal_version
    assert_includes report, '== Monthly growth (bigdecimal 4.1.1) =='
    assert_includes report, '== Sales tax (bigdecimal 3.3.1) =='
  end

  def test_each_plugin_uses_an_api_only_its_version_has
    # BigMath.cbrt exists only in bigdecimal 4.
    assert_includes report, 'Average +10.0% a month'
    # BigDecimal#precs exists only in bigdecimal 3.
    assert_includes report, 'TX  sales 1149.25  tax 71.83'
  end

  def test_float_patch_stays_in_sales_tax
    assert_includes report, 'Effective rate 6.10%'
    assert_includes report, '2026-07  1080.00  +8.0%'
    assert_includes report, '0.1 + 0.2 = 0.30000000000000004'
  end

  def test_host_never_loads_bigdecimal
    assert_includes report, 'BigDecimal defined: false'
  end

  private

  def report
    @report ||= run_example
  end

  def run_example
    output, error, status = Open3.capture3(unbundled_env, RbConfig.ruby, MAIN)
    assert status.success?, [output, error].reject(&:empty?).join("\n")
    output
  end

  def unbundled_env
    ENV
      .keys
      .grep(/\ABUNDLER?_/)
      .to_h { |key| [key, nil] }
      .merge('RUBYOPT' => nil, 'RUBYLIB' => nil, 'RUBY_BOX' => '1')
  end
end
