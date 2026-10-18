# frozen_string_literal: true

require_relative 'test_helper'
require 'fileutils'
require 'open3'
require 'rbconfig'
require 'tmpdir'

# `carton check` treats a gem Carton's gemspec as its manifest.
class CheckGemsTest < Minitest::Test
  Checks = Carton::Tools.const_get(:Checks)
  Project = Carton::Tools.const_get(:Project)
  ROOT = File.expand_path('../..', __dir__)

  def test_undeclared_gem_is_an_error
    billing = <<~RUBY
      Pricing = import 'pricing'
      Shipping = import 'shipping'
      require 'tax'
    RUBY
    problems =
      with_gems(
        {
          'billing' => {
            deps: %w[pricing],
            source: billing,
          },
          'pricing' => nil,
          'shipping' => nil,
          'tax' => nil,
        },
      )

    expected = [
      "import 'shipping' loads the shipping gem, which billing's gemspec " \
        "does not declare: add spec.add_dependency 'shipping'",
      "require 'tax' loads the tax gem, which billing's gemspec does not " \
        "declare: add spec.add_dependency 'tax'",
    ]
    assert_equal expected, problems.map(&:message)
    assert problems.all?(&:error?)
  end

  def test_own_files_default_gems_and_carton_are_allowed
    billing = "require 'billing/tax'\nrequire 'json_like'\nrequire 'carton'\n"
    problems =
      with_gems(
        {
          'billing' => {
            source: billing,
            files: {
              'billing/tax.rb' => '',
            },
          },
          'json_like' => {
            default: true,
          },
          'carton' => nil,
        },
      )

    assert_empty problems
  end

  # Only the gem Carton's own files are held to its gemspec. The app and
  # Cartons that are not gems may load any gem.
  def test_app_and_plain_cartons_are_not_checked
    problems =
      with_gems(
        { 'tools' => nil, 'extra' => nil },
        app: "import 'tools'\nrequire 'extra'\nimport_relative 'local'\n",
        local: "require 'extra'\n",
      )

    assert_empty problems
  end

  # The monorepo's Cartons declare what they import, so it checks clean
  # under its own bundle.
  def test_monorepo_example_declares_its_imports
    dir = File.join(ROOT, 'examples/monorepo')
    env = { 'BUNDLE_GEMFILE' => File.join(dir, 'Gemfile'), 'RUBY_BOX' => nil }
    output, status =
      Open3.capture2e(
        env,
        'bundle',
        'exec',
        RbConfig.ruby,
        File.join(ROOT, 'carton-tools/exe/carton'),
        'check',
        'main.rb',
        chdir: dir,
      )

    assert status.success?, output
    assert_match(/3 Cartons, 0 errors, 0 warnings/, output)
  end

  private

  # Write each gem under `gems/<name>/lib`, then check an app that imports
  # the first. Options (or nil) give `deps`, the Entrypoint `source`, other
  # `files`, and `default: true` for a default gem.
  def with_gems(gems, app: nil, local: nil)
    Dir.mktmpdir do |tmp|
      dir = File.realpath(tmp)
      specs =
        gems.map do |name, options|
          options ||= {}
          lib = File.join(dir, 'gems', name, 'lib')
          FileUtils.mkdir_p(lib)
          File.write(File.join(lib, "#{name}.rb"), options.fetch(:source, ''))
          options
            .fetch(:files, {})
            .each do |path, source|
              FileUtils.mkdir_p(File.dirname(File.join(lib, path)))
              File.write(File.join(lib, path), source)
            end
          spec(name, File.join(dir, 'gems', name), options)
        end
      File.write(
        File.join(dir, 'main.rb'),
        app || "import '#{gems.keys.first}'\n",
      )
      File.write(File.join(dir, 'local.rb'), local) if local
      load_path = gems.keys.map { |name| File.join(dir, 'gems', name, 'lib') }
      project = Project.new([File.join(dir, 'main.rb')], load_path:, specs:)
      Checks.new(project).problems
    end
  end

  def spec(name, path, options)
    spec =
      Gem::Specification.new do |s|
        s.name = name
        s.version = '1.0.0'
        options.fetch(:deps, []).each { |dep| s.add_dependency(dep) }
      end
    spec.full_gem_path = path
    default = options.fetch(:default, false)
    spec.define_singleton_method(:default_gem?) { default }
    spec
  end
end
