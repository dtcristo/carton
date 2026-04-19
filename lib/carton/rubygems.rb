# frozen_string_literal: true

module Carton
  # Temporary RubyGems split used by `Carton.bootstrap_rubygems!`.
  #
  # Ruby already gives each box its own `$LOAD_PATH`, but RubyGems was loaded in
  # the root box during startup. These patches duplicate the mutable RubyGems
  # registries that Bundler touches so bundled cartons can activate their own
  # gems without rewriting the caller's RubyGems view.
  module BoxedRubyGems
    # Mutable RubyGems state that should follow the current box, not the root.
    State =
      Struct.new(
        :loaded_specs,
        :paths,
        :activated_gem_paths,
        :pre_reset_hooks,
        :post_reset_hooks,
        :specification_record,
        :unresolved_deps,
        keyword_init: true,
      )

    module GemMethods
      def loaded_specs
        Carton.__send__(:boxed_rubygems_state).loaded_specs
      end

      def paths
        state = Carton.__send__(:boxed_rubygems_state)
        state.paths ||= Gem::PathSupport.new(ENV.to_hash)
      end

      def clear_paths
        state = Carton.__send__(:boxed_rubygems_state)
        state.paths = nil
        Gem::Specification.reset
        Gem::Security.reset if defined?(Gem::Security)
      end

      def activated_gem_paths
        state = Carton.__send__(:boxed_rubygems_state)
        state.activated_gem_paths ||= 0
      end

      def add_to_load_path(*paths)
        state = Carton.__send__(:boxed_rubygems_state)
        state.activated_gem_paths = activated_gem_paths + paths.size
        $LOAD_PATH.insert(Gem.load_path_insert_index, *paths)
      end

      def pre_reset(&hook)
        pre_reset_hooks << hook
      end

      def post_reset(&hook)
        post_reset_hooks << hook
      end

      def pre_reset_hooks
        Carton.__send__(:boxed_rubygems_state).pre_reset_hooks
      end

      def post_reset_hooks
        Carton.__send__(:boxed_rubygems_state).post_reset_hooks
      end
    end

    module SpecificationMethods
      def _all # :nodoc:
        specification_record.all
      end

      def stubs
        specification_record.stubs
      end

      def stubs_for(name)
        specification_record.stubs_for(name)
      end

      def stubs_for_pattern(pattern, match_platform = true) # :nodoc:
        specification_record.stubs_for_pattern(pattern, match_platform)
      end

      def add_spec(spec)
        specification_record.add_spec(spec)
      end

      def remove_spec(spec)
        specification_record.remove_spec(spec)
      end

      def all
        unless Gem::Deprecate.skip
          warn "NOTE: Specification.all called from #{caller(1, 1).first}"
        end
        _all
      end

      def all=(specs)
        specification_record.all = specs
      end

      def all_names
        specification_record.all_names
      end

      def each(&block)
        specification_record.each(&block)
      end

      def find_all_by_name(name, *requirements)
        specification_record.find_all_by_name(name, *requirements)
      end

      def find_by_path(path)
        specification_record.find_by_path(path)
      end

      def find_unloaded_by_path(path)
        specification_record.find_unloaded_by_path(path)
      end

      def find_inactive_by_path(path)
        specification_record.find_inactive_by_path(path)
      end

      def find_active_stub_by_path(path)
        specification_record.find_active_stub_by_path(path)
      end

      def latest_specs(prerelease = false)
        specification_record.latest_specs(prerelease)
      end

      def latest_spec_for(name)
        specification_record.latest_spec_for(name)
      end

      def reset
        state = Carton.__send__(:boxed_rubygems_state)

        Gem.pre_reset_hooks.each(&:call)
        state.specification_record = nil
        clear_load_cache

        unless unresolved_deps.empty?
          unresolved =
            unresolved_deps
              .filter_map do |name, dep|
                matching_versions = find_all_by_name(name)
                if dep.latest_version? && matching_versions.any?(&:default_gem?)
                  next
                end

                [dep, matching_versions.uniq(&:full_name)]
              end
              .to_h

          unless unresolved.empty?
            warn 'WARN: Unresolved or ambiguous specs during Gem::Specification.reset:'
            unresolved.each do |dep, versions|
              warn "      #{dep}"

              next if versions.empty?

              warn '      Available/installed versions of this gem:'
              versions.each { |spec| warn "      - #{spec.version}" }
            end
            warn "WARN: Clearing out unresolved specs. Try 'gem cleanup <gem>'"
            warn 'Please report a bug if this causes problems.'
          end

          unresolved_deps.clear
        end

        Gem.post_reset_hooks.each(&:call)
      end

      def specification_record
        state = Carton.__send__(:boxed_rubygems_state)
        state.specification_record ||= Gem::SpecificationRecord.new(dirs)
      end

      def unresolved_deps
        state = Carton.__send__(:boxed_rubygems_state)
        state.unresolved_deps ||=
          Hash.new { |hash, name| hash[name] = Gem::Dependency.new(name) }
      end
    end

    module SpecificationLoadMethods
      def load(file)
        Carton.__send__(:normalize_bundler_spec, super)
      end
    end

    module StubSpecificationMethods
      def spec
        Carton.__send__(:normalize_bundler_spec, super)
      end

      def to_spec
        Carton.__send__(:normalize_bundler_spec, super)
      end
    end

    module ResolverSpecGroupMethods
      def dependencies
        @dependencies ||=
          @specs
            .flat_map do |candidate|
              Carton.__send__(:expanded_dependencies_for, candidate)
            end
            .uniq
            .sort
      end
    end
  end

  class << self
    # Install Carton's box-local RubyGems patch in the current box.
    #
    # Call this before `require 'bundler/setup'` or before manual `gem` version
    # activation inside a carton.
    def bootstrap_rubygems!
      return if @boxed_rubygems_bootstrapped

      @boxed_rubygems_state = build_boxed_rubygems_state
      prepend_once(Gem.singleton_class, BoxedRubyGems::GemMethods)
      prepend_once(
        Gem::Specification.singleton_class,
        BoxedRubyGems::SpecificationMethods,
      )
      activate_bundler!
      mark_current_box_rubygems_bootstrapped!
      @boxed_rubygems_bootstrapped = true
    end

    private

    def activate_bundler!
      spec = Gem::Specification.find_all_by_name('bundler').max_by(&:version)
      return unless spec

      gem 'bundler', spec.version.to_s
      spec.full_require_paths.reverse_each do |path|
        $LOAD_PATH.unshift(path) unless $LOAD_PATH.include?(path)
      end
      unload_bundler!
      require 'bundler'
      install_bundler_spec_normalizers!
      Gem.loaded_specs.each_value do |loaded_spec|
        normalize_bundler_spec(loaded_spec)
      end
    end

    def unload_bundler!
      if defined?(Bundler)
        Bundler.rubygems.undo_replacements if Bundler.respond_to?(:rubygems)
        Bundler.reset! if Bundler.respond_to?(:reset!)
        Object.send(:remove_const, :Bundler)
      end

      if Gem.const_defined?(:VALIDATES_FOR_RESOLUTION, false)
        Gem.send(:remove_const, :VALIDATES_FOR_RESOLUTION)
      end

      $LOADED_FEATURES.reject! do |feature|
        expanded = File.expand_path(feature)
        expanded.end_with?('/bundler.rb') || expanded.include?('/bundler/')
      end
    end

    def install_bundler_spec_normalizers!
      return if @bundler_spec_normalizers_installed

      spec_singleton = Gem::Specification.singleton_class
      prepend_once(spec_singleton, BoxedRubyGems::SpecificationLoadMethods)

      if defined?(Gem::StubSpecification)
        prepend_once(
          Gem::StubSpecification,
          BoxedRubyGems::StubSpecificationMethods,
        )
      end

      require 'bundler/resolver/spec_group'
      prepend_once(
        Bundler::Resolver::SpecGroup,
        BoxedRubyGems::ResolverSpecGroupMethods,
      )

      @bundler_spec_normalizers_installed = true
    end

    def normalize_bundler_spec(spec)
      return spec unless spec && defined?(Bundler::MatchMetadata)
      return spec if spec.respond_to?(:expanded_dependencies)

      spec.extend(Bundler::MatchMetadata)
      spec
    end

    def expanded_dependencies_for(spec)
      normalize_bundler_spec(spec)
      Bundler::MatchMetadata.instance_method(:expanded_dependencies).bind_call(
        spec,
      )
    end

    def prepend_once(target, mod)
      return if target.ancestors.any? { |ancestor| ancestor.name == mod.name }

      target.prepend(mod)
    end

    def mark_current_box_rubygems_bootstrapped!
      return unless defined?(Ruby::Box)

      box = Ruby::Box.current
      return unless box.respond_to?(:mark_rubygems_bootstrapped, true)

      box.__send__(:mark_rubygems_bootstrapped)
    end

    def build_boxed_rubygems_state
      BoxedRubyGems::State.new(
        loaded_specs: build_boxed_loaded_specs,
        paths: Gem::PathSupport.new(ENV.to_hash),
        activated_gem_paths: Gem.activated_gem_paths,
        pre_reset_hooks: Gem.pre_reset_hooks.dup,
        post_reset_hooks: Gem.post_reset_hooks.dup,
        specification_record: build_boxed_specification_record,
        unresolved_deps:
          Hash.new { |hash, name| hash[name] = Gem::Dependency.new(name) },
      )
    end

    def build_boxed_specification_record
      record = Gem::SpecificationRecord.new(Gem::Specification.dirs)
      record.all = Gem::Specification._all.dup
      record
    end

    def build_boxed_loaded_specs
      load_paths = $LOAD_PATH.map { |path| File.expand_path(path) }

      Gem
        .loaded_specs
        .each_with_object({}) do |(name, spec), loaded_specs|
          keep =
            spec.default_gem? ||
              spec.full_require_paths.any? do |path|
                load_paths.include?(File.expand_path(path))
              end

          loaded_specs[name] = spec if keep
        end
    end

    def boxed_rubygems_state
      @boxed_rubygems_state
    end
  end
end
