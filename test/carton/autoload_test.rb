# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'tmpdir'

# An autoload a Carton registers loads in the Carton's Box, whichever Box
# references the constant first.
class AutoloadTest < Minitest::Test
  LAZY = <<~RUBY
    module Lazy
      autoload :Part, File.join(__dir__, 'lazy/part')
    end
    export_default Lazy
  RUBY
  PART = "Lazy::Part = Ruby::Box.current\n"

  # Ruby keeps an autoload in its own Box only for an exact Ruby::Box, so
  # Carton never subclasses it.
  def test_carton_boxes_are_plain_ruby_boxes
    exports =
      carton('entry.rb' => "export box_class: Ruby::Box.current.class\n")

    assert_equal Ruby::Box, exports.box_class
  end

  def test_autoload_triggered_by_the_importer_loads_in_the_carton
    lazy = carton('entry.rb' => LAZY, 'lazy/part.rb' => PART)

    refute_equal Ruby::Box.main, lazy::Part
    refute($LOADED_FEATURES.any? { |path| path.end_with?('lazy/part.rb') })
  end

  # `module Lazy` in part.rb resolves in the Carton's Box, so the importer's
  # name for the module does not matter.
  def test_autoload_works_under_another_name
    other =
      carton(
        'entry.rb' => LAZY,
        'lazy/part.rb' => "module Lazy\n  Part = :ok\nend\n",
      )

    assert_equal :ok, other::Part
  end

  def teardown
    FileUtils.rm_rf(@dir) if @dir
  end

  private

  # Autoloads run after `import` returns, so the files outlive the call.
  def carton(files)
    @dir = Dir.mktmpdir
    files.each do |path, source|
      FileUtils.mkdir_p(File.dirname(File.join(@dir, path)))
      File.write(File.join(@dir, path), source)
    end
    import File.join(@dir, 'entry.rb')
  end
end
