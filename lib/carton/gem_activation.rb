# frozen_string_literal: true

module Carton
  # Carries the caller's activated gems into a Carton Box.
  #
  # Optional Boxes copy Master, so they start with clean RubyGems state and
  # would auto-activate the newest installed version of any dependency. When
  # an Import resolves inside an activated gem, Carton activates that gem and
  # its runtime dependencies in the new Box at the caller's versions, so the
  # caller's lockfile (or plain `gem` calls) decides what the Carton sees.
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

    # Rebuild each spec in the current Box and activate it. Spec objects come
    # from another Box, so their own `activate` would update that Box; a YAML
    # round trip builds this Box's `Gem::Specification` without re-evaluating
    # gemspec files.
    def activate(specs)
      specs.each do |source|
        # Versions from another Box are a different class, so compare text.
        loaded = Gem.loaded_specs[source.name]
        next if loaded && loaded.version.to_s == source.version.to_s

        spec = Gem::Specification.from_yaml(source.to_spec.to_yaml)
        spec.loaded_from = source.loaded_from
        spec.full_gem_path = source.full_gem_path
        spec.activate
      end
    end

    def owner_of(feature, specs)
      specs
        .reject(&:default_gem?)
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
      return ordered if seen[spec.name] || spec.default_gem?

      seen[spec.name] = true
      spec.runtime_dependencies.each do |dependency|
        dependency_spec = loaded_specs[dependency.name]
        visit(dependency_spec, loaded_specs, ordered, seen) if dependency_spec
      end
      ordered << spec
    end
    private_class_method :visit
  end
end
