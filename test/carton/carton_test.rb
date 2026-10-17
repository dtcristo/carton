# frozen_string_literal: true

require_relative '../test_helper'

class CartonTest < Minitest::Test
  def test_export_is_available_globally
    assert_respond_to TOPLEVEL_BINDING.receiver, :export, include_all: true
  end

  # One rescue target for every error Carton raises itself.
  def test_errors_share_one_base_class
    assert_operator Carton::Error, :<, StandardError
    assert_operator Carton::ImportError, :<, Carton::Error
    assert_operator Carton::ExportError, :<, Carton::Error
    assert_operator Carton::GemfileNotFound, :<, Carton::Error
  end
end
