# frozen_string_literal: true

require_relative '../test_helper'

class GemActivationTest < Minitest::Test
  GemActivation = Carton.const_get(:GemActivation)
  Dependency = Struct.new(:name)
  Spec =
    Struct.new(:name, :deps, :root, :default, keyword_init: true) do
      def runtime_dependencies = deps.map { Dependency.new(_1) }
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

  def test_closure_skips_default_gems_and_survives_cycles
    specs = loaded(app: %w[a stdlib], a: %w[app], stdlib: [])
    specs['stdlib'].default = true

    assert_equal %w[a app], closure('/gems/app/lib/app.rb', specs).map(&:name)
  end

  # Each Box loads its own Bundler to apply the restriction, which may be a
  # different version than the caller's, so Bundler itself is never shared.
  def test_locked_and_closure_leave_out_bundler
    specs = loaded(app: %w[bundler money], money: [], bundler: [])
    bundled_box = Object.new.tap { |box| def box.eval(_) = true }

    assert_equal %w[app money],
                 GemActivation.locked(bundled_box, specs).map(&:name).sort
    assert_equal %w[money app],
                 closure('/gems/app/lib/app.rb', specs).map(&:name)
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
