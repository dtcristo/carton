# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
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
    assert_equal '2.0.0', result::VERSION
  end

  def test_single_export_is_shared
    # Each Entrypoint loads once per process, so repeat imports share it.
    a = import "#{FIXTURES}/single_export"
    b = import "#{FIXTURES}/single_export"
    assert_same a, b
  end

  def test_hash_export_is_shared
    a = import "#{FIXTURES}/hash_export"
    b = import "#{FIXTURES}/hash_export"
    assert_same a, b
  end

  def test_mixed_import_styles
    # Use import with absolute path
    user_class = import("#{FIXTURES}/single_export")

    # Use import_relative
    math = import_relative '../fixtures/bare_math'

    # Both work correctly in the same context
    alice = user_class.new('Alice')
    assert_equal 'Hello, Alice!', alice.greet
    assert_equal 10, math.add(3, 7)
  end

  def test_destructuring_with_rename
    import("#{FIXTURES}/bare_math") => { add: sum }
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

  def test_setup_bundle_auto_finds_parent_gemfile_and_restores_env
    previous = ENV['BUNDLE_GEMFILE']
    previous_lockfile = ENV['BUNDLE_LOCKFILE']
    result = import "#{FIXTURES}/auto_bundle/nested/auto_gemfile"

    assert_equal "#{FIXTURES}/auto_bundle", result.fetch(:selected_root)
    assert_equal [previous, previous_lockfile],
                 result.fetch_values(:restored, :restored_lockfile)
  end

  def test_setup_bundle_sets_up_only_requested_groups
    default_group = import "#{FIXTURES}/setup_bundle/default_group"
    tools_group = import "#{FIXTURES}/setup_bundle/tools_group"

    refute default_group.fetch(:tool_gem_loadable)
    assert_equal '0.1.0', tools_group.fetch(:tool_gem_version)
    assert_equal "#{FIXTURES}/setup_bundle", tools_group.fetch(:root)
    assert_equal [ENV['BUNDLE_GEMFILE']], tools_group.fetch_values(:env_gemfile)
  end

  def test_setup_bundle_leaves_process_env_unchanged
    script = <<~RUBY
      require 'json'
      require File.expand_path('lib/carton', Dir.pwd)

      before = ENV.to_h
      import File.expand_path('test/fixtures/setup_bundle/env_restore', Dir.pwd)
      changed = (before.keys | ENV.keys).reject { |key| before[key] == ENV[key] }

      puts JSON.generate(changed.sort)
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)
    assert_empty JSON.parse(output)
  end

  def test_setup_bundle_restores_env_when_bundler_fails
    previous = ENV['BUNDLE_GEMFILE']
    previous_lockfile = ENV['BUNDLE_LOCKFILE']
    result = import "#{FIXTURES}/setup_bundle/broken/entry"

    assert_equal 'Bundler::Dsl::DSLError', result.fetch(:error)
    assert_equal [previous, previous_lockfile],
                 result.fetch_values(:env_gemfile, :env_lockfile)
  end

  def test_setup_bundle_raises_when_explicit_gemfile_is_missing
    Dir.mktmpdir('carton-setup-bundle') do |dir|
      entry = File.join(dir, 'missing_gemfile.rb')
      File.write(entry, <<~RUBY)
        # frozen_string_literal: true

        Carton.setup_bundle(gemfile: 'Gemfile')
      RUBY

      error = assert_raises(StandardError) { import entry }
      assert_equal 'Carton::GemfileNotFound', error.class.name
    end
  end

  def test_setup_bundle_exposes_path_gems_to_name_based_imports
    script = <<~RUBY
      require 'json'
      require File.expand_path('lib/carton', Dir.pwd)

      gemfile = File.expand_path('examples/bundler/Gemfile', Dir.pwd)
      Carton.setup_bundle(gemfile:)

      before_loaded = Gem.loaded_specs.keys.sort
      before_load_path = $LOAD_PATH.to_a

      cartoned_gem = import 'cartoned_gem'
      resolved = $LOAD_PATH.resolve_feature_path('cartoned_gem')

      puts JSON.generate(
        version: cartoned_gem::VERSION,
        label: cartoned_gem.invoice_label('42'),
        resolved: resolved&.last,
        main_loaded_unchanged: Gem.loaded_specs.keys.sort == before_loaded,
        main_load_path_unchanged: $LOAD_PATH.to_a == before_load_path,
      )
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)

    payload = JSON.parse(output)
    assert_equal '0.1.0', payload.fetch('version')
    assert_equal 'INV-0042', payload.fetch('label')
    assert_match %r{/examples/bundler/cartoned_gem/lib/cartoned_gem\.rb\z},
                 payload.fetch('resolved')
    assert payload.fetch('main_loaded_unchanged')
    assert payload.fetch('main_load_path_unchanged')
  end

  # bigdecimal 4.1.1 is also installed, so without sharing the gem Carton's
  # Box would auto-activate the newest version instead of the locked 3.3.1.
  def test_gem_carton_uses_importer_locked_dependency_versions
    script = <<~RUBY
      require 'json'
      require File.expand_path('lib/carton', Dir.pwd)

      Carton.setup_bundle(gemfile: File.expand_path('test/fixtures/shared_gems/Gemfile', Dir.pwd))

      before_loaded = Gem.loaded_specs.keys.sort
      before_load_path = $LOAD_PATH.to_a

      priced_gem = import 'priced_gem'

      puts JSON.generate(
        bigdecimal_version: priced_gem[:bigdecimal_version],
        activated: priced_gem[:activated],
        main_loaded_unchanged: Gem.loaded_specs.keys.sort == before_loaded,
        main_load_path_unchanged: $LOAD_PATH.to_a == before_load_path,
        main_bigdecimal_required: $LOADED_FEATURES.any? { _1.end_with?('/bigdecimal.rb') },
      )
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)

    payload = JSON.parse(output)
    assert_equal '3.3.1', payload.fetch('bigdecimal_version')
    assert_equal '3.3.1', payload.fetch('activated')
    assert payload.fetch('main_loaded_unchanged')
    assert payload.fetch('main_load_path_unchanged')
    refute payload.fetch('main_bigdecimal_required')
  end

  # A bundled Importer's lockfile bounds what a gem Carton can load, as
  # `Bundler.setup` does for Main: undeclared locked gems load at their
  # locked version and unlocked gems fail.
  def test_gem_carton_of_bundled_importer_only_sees_locked_gems
    script = <<~RUBY
      require 'json'
      require File.expand_path('lib/carton', Dir.pwd)

      Carton.setup_bundle(gemfile: File.expand_path('test/fixtures/shared_gems/Gemfile', Dir.pwd))

      sloppy_gem = import 'sloppy_gem'

      puts JSON.generate(
        locked: sloppy_gem[:locked],
        unlocked: sloppy_gem[:unlocked],
        main_minitest: Gem.loaded_specs.key?('minitest'),
      )
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)

    payload = JSON.parse(output)
    assert_equal '3.3.1', payload.fetch('locked')
    assert_equal 'LoadError', payload.fetch('unlocked')
    refute payload.fetch('main_minitest')
  end

  # Gem activation loads Bundler, Psych and Date into the Carton's Box, but
  # they are Carton's support, not the Bare Carton's surface.
  def test_bare_gem_carton_exposes_only_what_its_entrypoint_defines
    script = <<~RUBY
      require File.expand_path('lib/carton', Dir.pwd)
      Carton.setup_bundle(gemfile: File.expand_path('test/fixtures/shared_gems/Gemfile', Dir.pwd))
      puts import('bigdecimal').keys.sort.join(' ')
      STDOUT.flush
      Process.exit!(0)
    RUBY

    assert_equal 'BigDecimal BigMath', run_boxed(script).strip
  end

  # The cache also compares locked gems a Carton loaded without declaring
  # them: sloppy_gem requires bigdecimal, which only the lockfile provides.
  def test_gem_carton_rejects_importer_locking_another_undeclared_gem_version
    script = <<~RUBY
      require File.expand_path('lib/carton', Dir.pwd)

      fixtures = File.expand_path('test/fixtures/shared_gems', Dir.pwd)
      Carton.setup_bundle(gemfile: File.join(fixtures, 'Gemfile'))

      import 'sloppy_gem' # loads bigdecimal 3.3.1 from the app's lockfile
      begin
        import File.join(fixtures, 'newer_sloppy/entry') # locks 4.1.1
        puts 'no error'
      rescue Carton::ImportError => e
        puts e.message
      end
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)
    assert_match(
      /sloppy_gem\.rb was imported with bigdecimal 3\.3\.1, but this import activates bigdecimal 4\.1\.1/,
      output,
    )
  end

  # The same check when sloppy_gem's first import is nested in another
  # Carton, whose Box is the loading Box while sloppy_gem loads.
  def test_nested_first_import_still_records_undeclared_locked_gems
    script = <<~RUBY
      require File.expand_path('lib/carton', Dir.pwd)

      fixtures = File.expand_path('test/fixtures/shared_gems', Dir.pwd)
      import File.join(fixtures, 'wrapper/entry') # imports sloppy_gem, 3.3.1
      begin
        import File.join(fixtures, 'newer_sloppy/entry') # locks 4.1.1
        puts 'no error'
      rescue Carton::ImportError => e
        puts e.message
      end
      STDOUT.flush
      Process.exit!(0)
    RUBY

    assert_match(
      /imported with bigdecimal 3\.3\.1, but this import activates bigdecimal 4\.1\.1/,
      run_boxed(script),
    )
  end

  LAZY_SLOPPY = <<~RUBY
    module SloppyGem
      def self.locked
        require 'bigdecimal'
        Gem.loaded_specs['bigdecimal'].version.to_s
      end
    end
    export SloppyGem
  RUBY

  # A gem the Carton requires lazily, after its import, counts at the next
  # import's check.
  def test_lazily_loaded_locked_gems_count_at_later_imports
    Dir.mktmpdir('carton-lazy-gem') do |dir|
      FileUtils.cp_r(File.expand_path('../fixtures/shared_gems', __dir__), dir)
      gems = File.join(dir, 'shared_gems')
      File.write(File.join(gems, 'sloppy_gem/lib/sloppy_gem.rb'), LAZY_SLOPPY)

      output = run_boxed(lazy_sloppy_script(gems))
      assert_match(/\A3\.3\.1$/, output)
      assert_match(
        /imported with bigdecimal 3\.3\.1, but this import activates bigdecimal 4\.1\.1/,
        output,
      )
    end
  end

  # Without Bundler, a gem Carton's default-gem dependencies keep the
  # versions the Importer activated, even when newer ones are installed: here
  # fake json and date 99.0.0 in a temporary gem home. date is also one of
  # Psych's requires, so it must be activated before any YAML spec rebuild.
  def test_gem_carton_keeps_the_importers_default_gem_versions
    %w[json date].each do |name|
      Dir.mktmpdir('carton-default-gem') do |home|
        install_fake_newer_default_gem(home, name)
        probe = File.join(home, 'probe')
        FileUtils.mkdir_p(File.join(probe, 'lib'))
        File.write(
          File.join(probe, 'lib', 'default_probe.rb'),
          "require '#{name}'\nexport version: Gem.loaded_specs['#{name}'].version.to_s\n",
        )
        gem_path = [home, *Gem.path].join(File::PATH_SEPARATOR)

        output, error, status =
          Open3.capture3(
            unbundled_env.merge('GEM_PATH' => gem_path),
            RbConfig.ruby,
            '-Ilib',
            '-e',
            default_probe_script(name, probe),
          )

        assert status.success?, [output, error].reject(&:empty?).join("\n")
        default_version, carton_version = output.split
        assert_equal default_version, carton_version, name
      end
    end
  end

  def test_gem_carton_imported_from_a_bundled_carton
    script = <<~'RUBY'
      require File.expand_path('lib/carton', Dir.pwd)

      # entry.rb sets up its own bundle and imports priced_gem from its Box.
      entry = import File.expand_path('test/fixtures/shared_gems/newer/entry', Dir.pwd)
      gem 'minitest' # not in any Carton's lockfile
      puts "#{entry[:priced_gem][:bigdecimal_version]} #{Gem.loaded_specs['minitest'] ? 'ok' : 'missing'}"
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)
    assert_equal '4.1.1 ok', output.strip
  end

  def test_gem_carton_rejects_importer_locking_a_different_version
    script = <<~RUBY
      require File.expand_path('lib/carton', Dir.pwd)

      fixtures = File.expand_path('test/fixtures/shared_gems', Dir.pwd)
      Carton.setup_bundle(gemfile: File.join(fixtures, 'Gemfile'))

      import 'priced_gem' # first importer locks bigdecimal 3.3.1
      begin
        import File.join(fixtures, 'newer/entry') # its bundle locks 4.1.1
        puts 'no error'
      rescue Carton::ImportError => e
        puts e.message
      end
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)
    assert_match(
      /priced_gem\.rb was imported with bigdecimal 3\.3\.1, but this import activates bigdecimal 4\.1\.1/,
      output,
    )
  end

  def test_bundler_example_imported_cartons_keep_separate_gem_versions
    script = <<~RUBY
      require 'json'

      examples = File.expand_path('examples/bundler', Dir.pwd)
      require File.expand_path('../../lib/carton', examples)

      Carton.setup_bundle(gemfile: File.join(examples, 'Gemfile'))

      Dir
        .glob(File.join(examples, 'cartons/*/lib'))
        .each { |dir| $LOAD_PATH.unshift(dir) unless $LOAD_PATH.include?(dir) }

      before_loaded = Gem.loaded_specs.keys.sort
      before_load_path = $LOAD_PATH.to_a

      math_helper = import 'math_helper'
      billing = import 'billing'
      cartoned_gem = import 'cartoned_gem'

      puts JSON.generate(
        math_helper_version: math_helper.fetch(:version),
        billing_rounding_version: billing.fetch(:rounding_version),
        cartoned_gem_version: cartoned_gem::VERSION,
        main_bigdecimal: Gem.loaded_specs['bigdecimal']&.version&.to_s,
        main_loaded_unchanged: Gem.loaded_specs.keys.sort == before_loaded,
        main_load_path_unchanged: $LOAD_PATH.to_a == before_load_path,
      )
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)

    payload = JSON.parse(output)
    assert_equal '4.1.1', payload.fetch('math_helper_version')
    assert_equal '3.3.1', payload.fetch('billing_rounding_version')
    assert_equal '0.1.0', payload.fetch('cartoned_gem_version')
    assert_nil payload.fetch('main_bigdecimal')
    assert payload.fetch('main_loaded_unchanged')
    assert payload.fetch('main_load_path_unchanged')
  end

  def test_import_without_boxes_explains_how_to_enable_them
    script = <<~SCRIPT
      require 'carton'
      %w[import import_relative].each do |method|
        __send__(method, 'json')
      rescue Carton::ImportError => e
        puts e.message
      end
    SCRIPT
    output, error, status =
      Open3.capture3(
        unbundled_env.merge('RUBY_BOX' => nil),
        RbConfig.ruby,
        '-Ilib',
        '-e',
        script,
      )

    assert status.success?, error
    assert_equal ['Carton needs Ruby::Box: run Ruby with RUBY_BOX=1'] * 2,
                 output.lines(chomp: true)
  end

  def test_monorepo_example_imports_path_gem_cartons_by_name
    output =
      run_boxed("load #{File.join(EXAMPLES, 'monorepo/main.rb').inspect}")

    assert_includes output, 'Invoice 42: 25.0'
    assert_includes output, 'Pricing uses bigdecimal 4.1.1'
    assert_includes output, 'Billing and the app share one pricing Carton: true'
    assert_includes output, 'Pricing::Rounding is private'
    assert_includes output, 'bigdecimal loaded in the Main Box: false'
  end

  def test_imported_file_can_require_carton_by_name
    Dir.mktmpdir('carton-require') do |dir|
      entry = File.join(dir, 'requires_carton.rb')
      File.write(entry, <<~RUBY)
        # frozen_string_literal: true

        require 'carton'

        export sets_up_bundles: Carton.respond_to?(:setup_bundle)
      RUBY

      result = import entry
      assert_equal true, result.fetch(:sets_up_bundles)
    end
  end

  def test_bundled_import_activates_inside_box_only
    script = <<~RUBY
      require 'json'
      require File.expand_path('lib/carton', Dir.pwd)

      math_helper_lib = File.expand_path('examples/bundler/cartons/math_helper/lib', Dir.pwd)
      $LOAD_PATH.unshift(math_helper_lib) unless $LOAD_PATH.include?(math_helper_lib)

      math_helper = import 'math_helper'

      puts JSON.generate(
        bigdecimal_version: math_helper.fetch(:version),
        root_bigdecimal: Gem.loaded_specs['bigdecimal']&.version&.to_s,
      )
      STDOUT.flush
      Process.exit!(0)
    RUBY

    output = run_boxed(script)

    payload = JSON.parse(output)
    assert_equal '4.1.1', payload.fetch('bigdecimal_version')
    assert_nil payload.fetch('root_bigdecimal')
  end

  private

  # Runs `script` in a fresh `RUBY_BOX=1` Ruby outside the dev bundle, as a
  # real process so native extensions and process exit are exercised, asserts
  # it succeeded, and returns its stdout.
  # A newer `name` that loads the real default gem's files, so code that
  # requires it still works and only the activated version tells them apart.
  def install_fake_newer_default_gem(home, name)
    lib = File.join(home, 'gems', "#{name}-99.0.0", 'lib')
    FileUtils.mkdir_p([lib, File.join(home, 'specifications')])
    real = File.join(RbConfig::CONFIG['rubylibdir'], "#{name}.rb")
    File.write(File.join(lib, "#{name}.rb"), "require #{real.inspect}\n")
    spec =
      Gem::Specification.new do |s|
        s.name = name
        s.version = '99.0.0'
        s.summary = 'fake'
        s.authors = ['Carton']
        s.files = ["lib/#{name}.rb"]
      end
    File.write(
      File.join(home, 'specifications', "#{name}-99.0.0.gemspec"),
      spec.to_ruby,
    )
  end

  # Activates the default `name`, then imports a gem Carton that requires it.
  def default_probe_script(name, probe)
    <<~RUBY
      require File.expand_path('lib/carton', Dir.pwd)
      default = Gem::Specification.find { |s| s.name == #{name.inspect} && s.default_gem? }
      default.activate
      spec = Gem::Specification.new do |s|
        s.name = 'default_probe'
        s.version = '0.1.0'
        s.summary = 'probe'
        s.authors = ['Carton']
        s.add_runtime_dependency(#{name.inspect})
      end
      spec.full_gem_path = #{probe.inspect}
      spec.activate
      puts [default.version, import('default_probe')[:version]].join(' ')
      STDOUT.flush
      Process.exit!(0)
    RUBY
  end

  # Calls the lazy sloppy_gem, then imports a Carton locking another
  # bigdecimal.
  def lazy_sloppy_script(gems)
    <<~RUBY
      require File.expand_path('lib/carton', Dir.pwd)

      Carton.setup_bundle(gemfile: #{File.join(gems, 'Gemfile').inspect})
      puts import('sloppy_gem').locked # requires bigdecimal 3.3.1 now
      begin
        import #{File.join(gems, 'newer_sloppy/entry').inspect} # locks 4.1.1
        puts 'no error'
      rescue Carton::ImportError => e
        puts e.message
      end
      STDOUT.flush
      Process.exit!(0)
    RUBY
  end

  def run_boxed(script)
    output, error, status =
      Open3.capture3(unbundled_env, RbConfig.ruby, '-Ilib', '-e', script)
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
