# frozen_string_literal: true

require_relative '../../../lib/carton'

# Bundle boundary: Main uses test/Gemfile; growth uses its own Gemfile.
Carton.setup_bundle
require 'minitest/autorun'

class GrowthTest < Minitest::Test
  Growth = import_relative '../plugins/growth'
  ORDERS = [{ month: '2026-06', state: 'CA', amount: '100.00' }.freeze].freeze

  def test_reports_through_the_plugin_interface
    assert_match(/bigdecimal 4\.1\.1/, Growth.title)
    assert_equal ['2026-06  100.00', 'Average 0.0% a month'],
                 Growth.call(ORDERS)
  end
end
