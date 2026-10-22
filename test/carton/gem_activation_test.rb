# frozen_string_literal: true

require_relative '../test_helper'

class GemActivationTest < Minitest::Test
  GemActivation = Carton.const_get(:GemActivation)
  Dependency = Struct.new(:name)
  Spec =
    Struct.new(:name, :deps, :root, :default, keyword_init: true) do
      def runtime_dependencies = deps.map { Dependency.new(it) }
      def full_require_paths = ["#{root}/lib"]
      def default_gem? = default
    end

  def test_closure_lists_owner_after_its_dependencies
    specs = loaded(app: %w[money json], money: %w[bigdecimal], bigdecimal: [])

    names = closure('/gems/app/lib/app.rb', specs).map(&:name)

    assert_equal %w[bigdecimal money app], names
  end

  def test_closure_is_empty_outside_activated_gems
    specs = loaded(app: [])

    assert_empty closure('/elsewhere/app.rb', specs)
    assert_empty closure('app', specs)
  end

  def test_closure_prefers_the_deepest_owning_require_path
    specs = loaded(outer: [], inner: [])
    specs['inner'].root = '/gems/outer/lib/vendor/inner'

    assert_equal ['inner'],
                 closure('/gems/outer/lib/vendor/inner/lib/x.rb', specs).map(
                   &:name
                 )
  end

  # A default gem the Importer activated is shared at its version: a new Box
  # would otherwise load the newest installed one.
  def test_closure_keeps_default_gems_and_survives_cycles
    specs = loaded(app: %w[a stdlib], a: %w[app], stdlib: [])
    specs['stdlib'].default = true

    assert_equal %w[a stdlib app],
                 closure('/gems/app/lib/app.rb', specs).map(&:name)
  end

  def test_locked_leaves_out_default_gems
    specs = loaded(app: %w[stdlib], stdlib: [])
    specs['stdlib'].default = true
    bundled_box =
      Object.new.tap { |box| box.define_singleton_method(:eval) { |_| true } }

    assert_equal %w[app], GemActivation.locked(bundled_box, specs).map(&:name)
  end

  # Each Box loads its own Bundler to apply the restriction, which may be a
  # different version than the Importer's, so Bundler itself is never shared.
  def test_locked_and_closure_leave_out_bundler
    specs = loaded(app: %w[bundler money], money: [], bundler: [])
    bundled_box =
      Object.new.tap { |box| box.define_singleton_method(:eval) { |_| true } }

    assert_equal %w[app money],
                 GemActivation.locked(bundled_box, specs).map(&:name).sort
    assert_equal %w[money app],
                 closure('/gems/app/lib/app.rb', specs).map(&:name)
  end

  # Each require path is a binary search over sorted features, so a sibling
  # directory sharing a name prefix does not count.
  def test_owning_selects_specs_with_a_loaded_feature
    specs = loaded(json: [], json_pure: [], money: []).values
    features = %w[
      /gems/json_pure/lib/json/pure.rb
      /gems/money/lib/money.rb
      /other/json/lib/json.rb
    ]

    names = GemActivation.owning(specs, features).map(&:name)

    assert_equal %w[json_pure money], names
  end

  def test_owning_is_empty_without_features
    assert_empty GemActivation.owning(loaded(json: []).values, [])
  end

  private

  def closure(feature, specs)
    GemActivation.closure(feature, specs)
  end

  def loaded(**graph)
    graph.to_h do |name, deps|
      [
        name.to_s,
        Spec.new(name: name.to_s, deps:, root: "/gems/#{name}", default: false),
      ]
    end
  end
end
