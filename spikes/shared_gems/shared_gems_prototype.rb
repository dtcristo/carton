# frozen_string_literal: true

require_relative 'assertions'

# Throwaway explicit dependency contract. No require interception or feature copying.
class SharedGemsPrototype
  BUILTINS = %w[
    Object
    Kernel
    String
    Array
    Hash
    Integer
    Numeric
    Time
    Date
    NilClass
    TrueClass
    FalseClass
    Symbol
    Module
    Class
  ].freeze
  SNAPSHOT = <<~'CODE'
    ->(names) do
      names.to_h do |name|
        target = Object.const_defined?(name, false) ? Object.const_get(name, false) : nil
        next [name, nil] unless target
        [name, [target, target.singleton_class].map do |mod|
          methods = {}
          %i[public protected private].each do |visibility|
            mod.send("#{visibility}_instance_methods", false).each do |name|
              method = mod.instance_method(name)
              method = method.super_method until method.nil? || method.owner.equal?(mod)
              methods[name] = [method, visibility] if method
            end
          end
          { target: mod, methods: methods, ancestors: mod.ancestors,
            inherited: mod.is_a?(Class) && mod.superclass ? mod.superclass.ancestors : [],
            visible: (mod.instance_methods + mod.private_instance_methods).uniq,
            constants: mod.constants(false).reject { |n| mod.autoload?(n) }.to_h { |n| [n, mod.const_get(n, false)] },
            autoloads: mod.constants(false).filter_map { |n| [n, mod.autoload?(n)] if mod.autoload?(n) },
            ivars: mod.instance_variables.to_h { |n| [n, mod.instance_variable_get(n)] },
            cvars: mod.class_variables(false).to_h { |n| [n, mod.class_variable_get(n)] } }
        end]
      end
    end
  CODE
  INSTALL = <<~'CODE'
    ->(entries, constants) do
      constants.each do |name, value|
        if Object.const_defined?(name, false)
          raise "Constant collision: #{name}" unless Object.const_get(name, false).equal?(value)
        else
          Object.const_set(name, value)
        end
      end
      entries.each do |entry|
        mod = Object.const_get(entry[:name], false)
        mod = mod.singleton_class if entry[:singleton]
        unless entry[:ambiguous_removals].empty?
          raise "Cannot distinguish removal from undef: #{entry[:name]} #{entry[:ambiguous_removals]}"
        end
        entry[:includes].reverse_each { |extension| mod.include(extension) unless mod.ancestors.include?(extension) }
        entry[:prepends].reverse_each { |extension| mod.prepend(extension) unless mod.ancestors.include?(extension) }
        entry[:remove].each { |name| mod.send(:remove_method, name) }
        entry[:undef].each { |name| mod.send(:undef_method, name) }
        entry[:methods].each do |name, (method, visibility)|
          mod.define_method(name, method)
          mod.send(visibility, name)
        end
        entry[:visibility].each { |name, visibility| mod.send(visibility, name) }
      end
    end
  CODE

  attr_reader :box, :manifest, :constants

  def initialize(gemfile: nil, extra_builtins: [])
    @builtins = BUILTINS + extra_builtins
    @box = Ruby::Box.new
    if gemfile
      saved_env = ENV.to_h
      begin
        ENV['BUNDLE_GEMFILE'] = gemfile
        ENV.delete('BUNDLE_LOCKFILE')
        @box.require(File.expand_path('bundle_setup.rb', __dir__))
      ensure
        ENV.replace(saved_env)
      end
    end
    @before = snapshot
    @constant_names = @box.constants(false)
    @manifest = []
    @constants = {}
  end

  def load(*features)
    features.each { |feature| @box.require(feature) }
    capture
    self
  end

  def capture
    @constants = @box.eval(<<~CODE).call(@constant_names)
        ->(before) do
          (Object.constants(false) - before).reject { |n| Object.autoload?(n) }
            .to_h { |n| [n, Object.const_get(n, false)] }
        end
      CODE
    @manifest = []
    snapshot.each do |name, states|
      next unless states
      # A newly loaded Date class is shared as an ordinary object, not patched.
      next unless @before[name]

      states.each_with_index do |after, i|
        before = @before.fetch(name).fetch(i)
        changed =
          after[:methods].reject { |n, entry| before[:methods][n] == entry }
        visibility, methods =
          changed
            .partition { |n, entry| before[:methods][n]&.first == entry.first }
            .map(&:to_h)
        visibility.transform_values!(&:last)
        added_ancestors = after[:ancestors] - before[:ancestors]
        index = after[:ancestors].index(after[:target])
        removed = before[:methods].keys - after[:methods].keys
        hidden = before[:visible] - after[:visible]
        @manifest << {
          name: name,
          singleton: i == 1,
          methods: methods,
          visibility: visibility,
          remove: removed - hidden,
          undef: hidden - removed,
          ambiguous_removals: removed & hidden,
          prepends: after[:ancestors].take(index) & added_ancestors,
          includes:
            (after[:ancestors].drop(index + 1) & added_ancestors) -
              after[:inherited],
          unsupported:
            %i[constants autoloads ivars cvars].reject do |key|
              before[key] == after[key]
            end,
        }
      end
    end
    self
  end

  def install(target)
    target.eval(INSTALL).call(@manifest, @constants)
    target
  end

  def create_box = install(Ruby::Box.new)

  def summary
    @manifest.map do |entry|
      entry.merge(
        methods: entry[:methods].keys,
        includes: entry[:includes].map(&:name),
        prepends: entry[:prepends].map(&:name),
      )
    end
  end

  private

  def snapshot = @box.eval(SNAPSHOT).call(@builtins)
end
