# frozen_string_literal: true

module Carton
  # Process-wide record of loaded Cartons, keyed by Entrypoint path.
  #
  # The Main Box creates one instance and every Carton Box receives that same
  # object, so each Entrypoint loads once no matter which Carton imports it.
  # Ruby objects are shared across Boxes; only definitions are Box-local, so
  # the Main Box's loader builds every Carton. A cached value is then a
  # `Carton::Exports` or `Carton::Box` from the Main Box regardless of which
  # Carton imported it first.
  class ImportCache
    def initialize(&loader)
      @loader = loader
      @values = {}
      @gem_versions = {}
      @loading = {}
      @lock = Thread::Mutex.new
    end

    # Load `target` once per Entrypoint path. Targets without an absolute
    # path are loaded uncached. Nested imports on the owning thread re-enter
    # without waiting on the lock.
    def import(target)
      return @loader.call(target) unless File.absolute_path?(target.feature)

      key = File.realpath(target.feature)
      return fetch(key, target) if @lock.owned?

      @lock.synchronize { fetch(key, target) }
    end

    private

    def fetch(key, target)
      if @values.key?(key)
        check_gem_versions(key, target)
        return @values[key]
      end
      raise "circular import: #{key}" if @loading.key?(key)

      @loading[key] = true
      begin
        @values[key] = @loader.call(target)
        @gem_versions[key] = gem_versions(target)
        @values[key]
      ensure
        @loading.delete(key)
      end
    end

    # A cached Carton keeps the gem versions its first importer activated.
    # Raise instead of silently sharing it with an importer that locks a
    # different version of one of those gems.
    def check_gem_versions(key, target)
      cached = @gem_versions.fetch(key)
      gem_versions(target).each do |name, version|
        next if cached.fetch(name, version) == version

        raise "#{key} was imported with #{name} #{cached[name]}, " \
                "but this import activates #{name} #{version}"
      end
    end

    def gem_versions(target)
      (target.gems || []).to_h { |spec| [spec.name, spec.version.to_s] }
    end
  end
end
