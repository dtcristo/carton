# frozen_string_literal: true

require_relative '../../../lib/carton'

# Bundle boundary: Main uses test/Gemfile; webhook uses its own Gemfile.
Carton.setup_bundle
require 'minitest/autorun'

class WebhookTest < Minitest::Test
  Webhook = import_relative '../plugins/webhook'
  ORDERS = [{ month: '2026-06', state: 'CA', amount: 100.0 }.freeze].freeze

  def test_reports_through_the_plugin_interface
    assert_match(/faraday 2\./, Webhook.title)
    assert_equal ['2026-06  100.0', 'POST /month-end  202  1 months'],
                 Webhook.call(ORDERS)
  end
end
