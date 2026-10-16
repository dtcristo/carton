# frozen_string_literal: true

require_relative '../test_helper'

class CartonTest < Minitest::Test
  def test_export_default_is_available_globally
    assert_respond_to TOPLEVEL_BINDING.receiver,
                      :export_default,
                      include_all: true
  end
end
