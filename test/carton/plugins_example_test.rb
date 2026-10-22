# frozen_string_literal: true

require_relative '../test_helper'
require 'open3'
require 'rbconfig'

# Runs examples/plugins/main.rb as a real `RUBY_BOX=1` process outside the dev
# bundle, so each plugin sets up its own bundle as it would in an app.
class PluginsExampleTest < Minitest::Test
  MAIN = File.expand_path('../../examples/plugins/main.rb', __dir__)

  def test_each_plugin_runs_on_its_own_faraday_version
    assert_includes report, '== CRM (faraday 1.10.6) =='
    assert_includes report, '== Webhook (faraday 2.15.0) =='
  end

  def test_each_plugin_uses_an_api_only_its_version_has
    # `request :basic_auth` exists only in faraday 1, through crm_client.
    assert_includes report, 'TX  1149.25  synced'
    # `request :authorization, :basic, ...` exists only in faraday 2.
    assert_includes report, 'POST /month-end  202  4 months'
  end

  def test_float_patch_stays_in_crm
    assert_includes report, 'CA  2211.50  synced'
    assert_includes report, '2026-07  1080.0'
    assert_includes report, '0.1 + 0.2 = 0.30000000000000004'
  end

  def test_host_never_loads_faraday
    assert_includes report, 'Faraday defined: false'
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
