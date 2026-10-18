# frozen_string_literal: true

require_relative '../test_helper'

# `export` only declares a Carton's surface from the
# Entrypoint being imported, so Carton-aware files still work under `require`.
class PlainRequireTest < Minitest::Test
  CARTON = File.expand_path('../../lib/carton', __dir__)
  DUAL = File.expand_path('../fixtures/dual', __dir__)

  def test_export_is_inert_under_plain_require
    box = plain_box

    assert_equal 'hi', box.eval("require #{"#{DUAL}/named".inspect}; shout")
    assert_equal({ value: :v }, box.eval('export value: :v'))
    assert_equal 1, box.eval('export 1; export 1')
  end

  def test_export_still_validates_arguments_under_plain_require
    box = plain_box

    # The plain Box loaded its own Carton, so its error class is its own.
    error =
      assert_raises(StandardError) { box.eval('export def whisper = "hi"') }
    assert_equal 'Carton::ExportError', error.class.name
    assert_raises(ArgumentError) { box.eval('export') }
  end

  def test_only_the_entrypoint_declares_exports
    assert_equal %i[entry library], import("#{DUAL}/entry")[:value]
  end

  private

  # A Box that is not a Carton, like an app that never imports.
  def plain_box
    box = Ruby::Box.new
    box.require(CARTON)
    box
  end
end
