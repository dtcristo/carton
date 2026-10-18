# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'

# Characterizes the Ruby::Box behaviour Carton documents, so a Ruby release
# that changes it fails here first. See docs/internals/how-boxes-work.md.
class BoxSemanticsTest < Minitest::Test
  # Builtin classes are copy-on-write per Box.
  def test_builtin_monkey_patch_stays_in_its_box
    patcher = Ruby::Box.new
    other = Ruby::Box.new
    patcher.eval('class String; def carton_semantics_probe = 1; end')

    assert patcher.eval('String.method_defined?(:carton_semantics_probe)')
    refute other.eval('String.method_defined?(:carton_semantics_probe)')
    refute String.method_defined?(:carton_semantics_probe)
  end

  # A class created in a Carton's Box has one shared definition.
  def test_reopening_a_carton_class_changes_it_inside_the_carton
    Dir.mktmpdir do |dir|
      File.write("#{dir}/widget.rb", <<~RUBY)
        class Widget
          def self.label = respond_to?(:extra) ? 'reopened' : 'original'
        end

        export Widget
      RUBY

      widget = import "#{dir}/widget"
      assert_equal 'original', widget.label

      widget.define_singleton_method(:extra) { :from_main }
      assert_equal 'reopened', widget.label
    end
  end
end
