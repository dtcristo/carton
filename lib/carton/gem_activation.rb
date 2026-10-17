# frozen_string_literal: true

module Carton
  # Carries the caller's activated gems into a Carton Box.
  #
  # Optional Boxes copy Master, so they start with clean RubyGems state and
  # would auto-activate the newest installed version of any dependency. When
  # an Import resolves inside an activated gem, Carton activates that gem and
  # its runtime dependencies in the new Box at the caller's versions, so the
  # caller's lockfile (or plain `gem` calls) decides what the Carton sees.
  #
  # When the caller ran Bundler setup, the Box is also restricted to the
  # caller's locked gems, as `Bundler.setup` restricts Main: every locked gem
  # is activated at its locked version and anything else fails to load.
  module GemActivation
    module_function

    # The non-default gem in `loaded_specs` that owns `feature`, plus its
    # activated runtime dependencies, dependencies first. Empty when no
    # activated gem owns the file.
    def closure(feature, loaded_specs)
      owner = owner_of(feature, loaded_specs.values)
      return [] unless owner

      visit(owner, loaded_specs, [], {})
    end

    # The caller's locked gems when `box` ran Bundler setup, otherwise nil.
    # Bundler marks every locked spec as loaded, so these are the shareable
    # entries of its `Gem.loaded_specs`.
    def locked(box, loaded_specs)
      return unless bundled?(box)

      loaded_specs.values.select { |spec| shareable?(spec) }
    end

    # The specs that own at least one of `features`, by require path. Sorted
    # features let each directory check be a binary search, so a large bundle
    # stays cheap.
    def owning(specs, features)
      sorted = features.sort
      specs.select do |spec|
        spec.full_require_paths.any? do |dir|
          prefix = "#{dir}/"
          sorted.bsearch { |feature| feature >= prefix }&.start_with?(prefix)
        end
      end
    end

    # Rebuild specs in the current Box and activate them. With `locked`, the
    # Box is restricted to those specs and all of them are activated, as
    # `Bundler.setup` does, since RubyGems does not auto-activate under
    # Bundler's restricted view. Spec objects come from another Box, so their
    # own `activate` would update that Box; a YAML round trip builds this Box's
    # `Gem::Specification` without re-evaluating gemspec files.
    def activate(specs, locked = nil)
      rebuilt = (locked || specs).map { |source| rebuild(source) }
      restrict_to(rebuilt) if locked

      rebuilt.each do |spec|
        loaded = Gem.loaded_specs[spec.name]
        spec.activate unless loaded && loaded.version == spec.version
      end
    end

    def rebuild(source)
      spec = Gem::Specification.from_yaml(source.to_spec.to_yaml)
      spec.loaded_from = source.loaded_from
      spec.full_gem_path = source.full_gem_path
      spec
    end
    private_class_method :rebuild

    # Bundler has no public API for "restrict this Box to these specs", so the
    # two Bundler internals Carton relies on live here. `@replaced_methods`
    # is non-empty once `Bundler.setup` has replaced RubyGems entrypoints.
    # `replace_entrypoints` is the strict half of `Bundler::Runtime#setup`,
    # without resolution, `ENV` exports, or lockfile writes. See
    # docs/internals/upstream.md.
    def bundled?(box)
      box.eval(
        'defined?(Bundler.rubygems) && ' \
          'Bundler.rubygems.instance_variable_get(:@replaced_methods)&.any?',
      )
    end
    private_class_method :bundled?

    def restrict_to(specs)
      require 'bundler'
      Bundler.rubygems.replace_entrypoints(specs)
    end
    private_class_method :restrict_to

    def owner_of(feature, specs)
      specs
        .select { |spec| shareable?(spec) }
        .filter_map do |spec|
          dir =
            spec.full_require_paths.find do |path|
              feature.start_with?("#{path}/")
            end
          [dir.length, spec] if dir
        end
        .max_by(&:first)
        &.last
    end
    private_class_method :owner_of

    def visit(spec, loaded_specs, ordered, seen)
      return ordered if seen[spec.name] || !shareable?(spec)

      seen[spec.name] = true
      spec.runtime_dependencies.each do |dependency|
        dependency_spec = loaded_specs[dependency.name]
        visit(dependency_spec, loaded_specs, ordered, seen) if dependency_spec
      end
      ordered << spec
    end
    private_class_method :visit

    # Default gems already load in every Box. Bundler is left out too: each
    # Box loads its own copy to apply the restriction, possibly a different
    # version than the caller's, and activating the caller's on top of it
    # raises Gem::LoadError.
    def shareable?(spec)
      !spec.default_gem? && spec.name != 'bundler'
    end
    private_class_method :shareable?
  end
end
