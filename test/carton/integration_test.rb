# frozen_string_literal: true

require_relative '../test_helper'
require 'json'
require 'open3'
require 'rbconfig'
require 'tmpdir'

class IntegrationTest < Minitest::Test
  FIXTURES = File.expand_path('../fixtures', __dir__)
  EXAMPLES = File.expand_path('../../examples', __dir__)

  def test_nested_import_relative_chain
    # advanced.rb uses import_relative to load basic.rb, re-exports add
    result = import_relative '../fixtures/math_tools/advanced'
    assert_in_delta 314.159, result.circle_area(10)
    assert_equal 20, result.add(8, 12)
    assert_equal '2.0.0', result.version
  end

  def test_single_export_isolation
    # Each import creates a fresh box — no leaking between imports
    a = import "#{FIXTURES}/single_export"
    b = import "#{FIXTURES}/single_export"
    refute_same a, b
    assert_equal a.name, b.name
  end

  def test_hash_export_isolation
    a = import "#{FIXTURES}/hash_export"
    b = import "#{FIXTURES}/hash_export"
    refute_same a, b
  end

  def test_mixed_import_styles
    # Use import with absolute path
    user_class = import "#{FIXTURES}/single_export"

    # Use import_relative
    math = import_relative '../fixtures/hash_export'

    # Both work correctly in the same context
    alice = user_class.new('Alice')
    assert_equal 'Hello, Alice!', alice.greet
    assert_equal 10, math.add(3, 7)
  end

  def test_destructuring_with_rename
    import("#{FIXTURES}/hash_export") => { add: sum }
    assert_equal 42, sum.(20, 22)
  end

  def test_re_export_through_chain
    # advanced.rb imports basic.rb's add and re-exports it
    result = import_relative '../fixtures/math_tools/advanced'
    assert_equal 100, result.add(40, 60)
  end

  def test_import_relative_from_within_box
    # relative_importer.rb uses import_relative internally to load single_export.rb
    result = import_relative '../fixtures/relative_importer'
    assert_equal 'Hello, World!', result.greeting
  end

  def test_with_bundle_auto_finds_parent_gemfile_inside_box
    previous = ENV['BUNDLE_GEMFILE']
    previous_lockfile = ENV['BUNDLE_LOCKFILE']
    result = import "#{FIXTURES}/with_bundle/nested/auto_gemfile"

    assert_equal "#{FIXTURES}/with_bundle/Gemfile", result.fetch(:selected)
    assert_equal "#{FIXTURES}/with_bundle/Gemfile.lock",
                 result.fetch(:selected_lockfile)
    if previous
      assert_equal previous, result.fetch(:restored)
    else
      assert_nil result.fetch(:restored)
    end

    if previous_lockfile
      assert_equal previous_lockfile, result.fetch(:restored_lockfile)
    else
      assert_nil result.fetch(:restored_lockfile)
    end
  end

  def test_with_bundle_raises_when_explicit_gemfile_is_missing
    Dir.mktmpdir('carton-with-bundle') do |dir|
      entry = File.join(dir, 'missing_gemfile.rb')
      File.write(entry, <<~RUBY)
          # frozen_string_literal: true

          Carton.with_bundle('Gemfile') do
            export_default true
          end
        RUBY

      error = assert_raises(StandardError) { import entry }
      assert_equal 'Carton::GemfileNotFound', error.class.name
    end
  end

  def test_imported_file_can_require_carton_by_name
    Dir.mktmpdir('carton-require') do |dir|
      entry = File.join(dir, 'requires_carton.rb')
      File.write(entry, <<~RUBY)
          # frozen_string_literal: true

          require 'carton'

          export bootstraps_rubygems: Carton.respond_to?(:bootstrap_rubygems!)
        RUBY

      result = import entry
      assert_equal true, result.fetch(:bootstraps_rubygems)
    end
  end

  def test_bundled_import_activates_inside_box_only
    script = <<~'RUBY'
      require 'json'
      require File.expand_path('lib/carton', Dir.pwd)

      adventure_lib = File.expand_path('examples/bundler/cartons/adventure/lib', Dir.pwd)
      $LOAD_PATH.unshift(adventure_lib) unless $LOAD_PATH.include?(adventure_lib)

      adventure = import 'adventure'

      puts JSON.generate(
        bigdecimal_version: adventure.version,
        root_bigdecimal: Gem.loaded_specs['bigdecimal']&.version&.to_s,
      )
      STDOUT.flush
      Process.exit!(0)
    RUBY

    env = ENV.keys.grep(/\ABUNDLE_/).to_h { |key| [key, nil] }
    env['RUBYOPT'] = nil
    env['RUBYLIB'] = nil
    env['RUBY_BOX'] = '1'
    output, error, status = Open3.capture3(env, RbConfig.ruby, '-e', script)

    assert status.success?, [output, error].reject(&:empty?).join("\n")

    payload = JSON.parse(output)
    assert_equal '4.1.1', payload.fetch('bigdecimal_version')
    assert_nil payload.fetch('root_bigdecimal')
  end
end
